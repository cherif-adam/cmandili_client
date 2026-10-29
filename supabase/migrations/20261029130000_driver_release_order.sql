-- ============================================================================
-- CMANDILI / Amana — « Je ne peux pas livrer » : le retrait du livreur
--
-- À lancer dans le SQL Editor APRÈS 20261029120000_orders_write_guard, puis
-- à enregistrer avec `supabase migration repair --status applied 20261029130000`.
--
-- ── CONSTAT (live, 29/10, test en transaction annulée) ──────────────────────
-- Le bouton de l'app livreur écrivait lui-même sur orders (driver_id et
-- assigned_driver_id vidés, statut 'ready', son id dans passed_driver_ids),
-- puis une ligne 'driver_relay' dans settlements. Sur le live :
--   1. la RLS de orders refuse (aucune policy n'accepte driver_id vide pour
--      un livreur) : le livreur voit « Échec : … » et reste bloqué ;
--   2. 'driver_relay' n'est pas un type permis par settlements_type_check ;
--   3. et même permise, cette ligne aurait payé le livreur tout de suite :
--      update_wallet_balance ajoute chaque nouvelle ligne au solde, quel que
--      soit son statut. L'app promet pourtant « crédité par l'admin » ;
--   4. rien ne remettait la commande dans la cascade d'offres.
--
-- ── CE QUE FAIT CE FICHIER ──────────────────────────────────────────────────
-- driver_release_order(commande, motif), SECURITY DEFINER, appelée par l'app
-- livreur. D'un seul coup :
--   - seul le livreur affecté peut se retirer ; un écran pas à jour reçoit
--     'not_assigned' et rien ne change ;
--   - driver_id, l'offre en cours et l'alerte « aucun livreur » sont vidés ;
--     son id rejoint passed_driver_ids pour qu'on ne la lui repropose pas ;
--   - après la prise en charge, la commande redevient 'ready' (le suivant
--     vient récupérer la marchandise) ; avant, elle garde son statut ;
--   - sa ligne deliveries passe à 'cancelled' ;
--   - après la prise en charge, le trajet fait devient une demande à l'admin
--     (support_tickets « Trajet partiel #… »), réglée par un crédit manuel :
--     aucune ligne de settlements, donc aucun paiement sans validation ;
--   - si la commande est prête, retour dans la cascade comme pass_order_offer
--     et rotate_expired_offers : le plus proche livreur qui ne l'a pas refusée
--     (7 km puis le rayon élargi), sinon le partenaire est prévenu. Pas encore
--     prête : elle attend le passage à 'ready', qui lance la distribution.
-- Et settlements_type_check accepte 'correction' (écritures inverses de
-- l'admin, utilisées par le script des doublons).
-- ============================================================================


-- ── 1. Type 'correction' pour les règlements ────────────────────────────────
alter table public.settlements drop constraint if exists settlements_type_check;
alter table public.settlements add constraint settlements_type_check
  check (type = any (array['order_earning', 'commission_deduction', 'payout', 'collection',
                           'manual_topup', 'loyalty_subsidy', 'correction']));


-- ── 2. Le retrait ───────────────────────────────────────────────────────────
create or replace function public.driver_release_order(p_order_id uuid, p_reason text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver       public.drivers%rowtype;
  v_order        public.orders%rowtype;
  v_after_pickup boolean;
  v_status       text;
  v_next         uuid;
  v_fallback     boolean := false;
begin
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'Un motif est obligatoire';
  end if;

  select * into v_driver from public.drivers where user_id = auth.uid();
  if v_driver.id is null then
    raise exception 'Seul un livreur peut se retirer d''une course';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  -- Écran pas à jour : la course a déjà été reprise ou réattribuée.
  if not found or v_order.driver_id is distinct from v_driver.id then
    return 'not_assigned';
  end if;
  if v_order.status in ('delivered', 'cancelled') then
    raise exception 'Cette commande est déjà terminée';
  end if;

  v_after_pickup := v_order.status in ('pickedUp', 'onTheWay');
  v_status := case when v_after_pickup then 'ready' else v_order.status end;

  update public.orders
     set driver_id             = null,
         assigned_driver_id    = null,
         assignment_expires_at = null,
         no_driver_notified_at = null,
         status                = v_status,
         passed_driver_ids     = case
           when v_driver.id = any (coalesce(passed_driver_ids, array[]::uuid[])) then passed_driver_ids
           else coalesce(passed_driver_ids, array[]::uuid[]) || v_driver.id
         end
   where id = p_order_id;

  update public.deliveries
     set status = 'cancelled', updated_at = now()
   where order_id = p_order_id
     and driver_id = v_driver.id
     and status not in ('delivered', 'cancelled');

  if v_after_pickup then
    -- Best effort, comme les autres demandes à l'admin : le retrait doit
    -- passer même si la demande ne s'écrit pas.
    begin
      insert into public.support_tickets (user_id, subject, message, status)
      values (
        v_driver.user_id,
        'Trajet partiel #' || upper(substring(p_order_id::text, 1, 8)),
        'Le livreur ' || v_driver.id::text || ' s''est retiré de la commande ' || p_order_id::text
          || ' après la prise en charge. Motif : ' || btrim(p_reason)
          || '. Frais de livraison de la commande : ' || coalesce(v_order.delivery_fee::text, '?')
          || ' DT. À créditer par un crédit manuel si le trajet est confirmé.',
        'open'
      );
    exception when others then
      raise warning 'driver_release_order: demande de trajet partiel non créée : %', sqlerrm;
    end;
  end if;

  if v_status = 'ready' then
    v_next := public.next_eligible_driver(p_order_id);
    if v_next is null then
      v_next := public.next_eligible_driver(p_order_id, public.driver_fallback_radius_km());
      v_fallback := v_next is not null;
    end if;
    if v_next is not null then
      perform public.offer_order_to_driver(p_order_id, v_next, 30, v_fallback);
    else
      perform public.notify_partner_no_drivers(p_order_id);
    end if;
  end if;

  return 'released';
end;
$$;

revoke all on function public.driver_release_order(uuid, text) from public, anon;
grant execute on function public.driver_release_order(uuid, text) to authenticated, service_role;


-- ── Contrôle : si quelque chose manque, tout le fichier est annulé ─────────
do $check$
begin
  if (select prosecdef from pg_proc
       where oid = to_regprocedure('public.driver_release_order(uuid, text)')) is distinct from true then
    raise exception 'driver_release_order incomplet : fonction absente ou pas SECURITY DEFINER';
  end if;
  if has_function_privilege('anon', 'public.driver_release_order(uuid, text)', 'execute')
     or not has_function_privilege('authenticated', 'public.driver_release_order(uuid, text)', 'execute') then
    raise exception 'driver_release_order incomplet : droits d''exécution';
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.settlements'::regclass and conname = 'settlements_type_check'
                    and pg_get_constraintdef(oid) like '%correction%') then
    raise exception 'driver_release_order incomplet : type correction absent';
  end if;
end
$check$;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : quatre colonnes à true.
select coalesce((select prosecdef from pg_proc
                  where oid = to_regprocedure('public.driver_release_order(uuid, text)')), false) as retrait_pret,
       coalesce(has_function_privilege('authenticated', to_regprocedure('public.driver_release_order(uuid, text)'), 'execute')
                and not has_function_privilege('anon', to_regprocedure('public.driver_release_order(uuid, text)'), 'execute'),
                false) as retrait_livreurs_seulement,
       exists (select 1 from pg_constraint
                where conrelid = 'public.settlements'::regclass and conname = 'settlements_type_check'
                  and pg_get_constraintdef(oid) like '%correction%') as type_correction,
       exists (select 1 from pg_trigger
                where tgrelid = 'public.orders'::regclass and tgenabled = 'O'
                  and tgname = 'aa_guard_status_by_role') as garde_ecritures_appliquee;
