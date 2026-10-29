-- ============================================================================
-- CMANDILI / Amana — Ce que chaque app peut écrire sur une commande
--
-- À lancer dans le SQL Editor APRÈS 20261028120000_security_lockdown et
-- 20260820110000_guard_delivered_terminal, puis à enregistrer avec
-- `supabase migration repair --status applied 20261029120000`.
--
-- ── CONSTAT (live, 29/10, test en transaction annulée) ──────────────────────
-- 1. Le garde-fou des colonnes ne fait plus rien. 20260925200000 a redéclaré
--    guard_orders_column_scope en SECURITY DEFINER (l'original de
--    20260703130000 disait « do not change to DEFINER »). Dans une fonction
--    DEFINER, current_user est le propriétaire : le test « chemin serveur ? »
--    est toujours vrai et la fonction sort sans rien vérifier. Un client a pu
--    passer le total de sa commande à 0,001 DT et les frais de livraison à 0.
-- 2. Le statut n'est contrôlé pour personne : le client peut écrire
--    n'importe quel statut sur sa commande (par exemple 'delivered', ce qui
--    prélève les commissions de la boutique et du livreur), le livreur peut
--    annuler, le partenaire peut revenir en arrière.
--
-- ── CE QUE LES APPS ÉCRIVENT VRAIMENT (relevé du code du 29/10) ─────────────
--   client     statut 'cancelled' + motif avant la prise en charge
--              (cancelOrderByCustomer, cancelOrder après un paiement refusé) ;
--              colis en route → 'delivered' (« le destinataire l'a reçu »)
--   partenaire pending → confirmed → preparing → ready (ou confirmed → ready),
--              ready → pickedUp / onTheWay ; refus avec motif
--              (cancelOrderByPartner) ; livraison par la boutique
--              (self_delivery + onTheWay, puis → delivered). Depuis le 29/10,
--              « livrée » n'est permise au partenaire que pour une commande
--              qu'il livre lui-même : portée par un livreur, c'est le livreur
--              qui la livre.
--   livreur    prise de course (driver_id vide → lui) ; avant la prise en
--              charge → pickedUp (colis : → onTheWay) ; pickedUp → onTheWay ;
--              → delivered ; reçu de facture (bill_receipt_url)
--   Tout le reste passe par des fonctions SECURITY DEFINER (offres, dispatch,
--   colis, confirmation de réception, règlements, suppression de compte, et
--   « je ne peux pas livrer » : driver_release_order, 20261029130000) :
--   elles tournent sous leur propriétaire et ne sont pas concernées.
--
-- ── CE QUE FAIT CE FICHIER ──────────────────────────────────────────────────
-- 1. guard_orders_column_scope repasse en SECURITY INVOKER, avec les colonnes
--    ci-dessus et rien d'autre. Ajout par rapport à l'original : les
--    colonnes d'annulation pour le partenaire.
-- 2. Nouveau aa_guard_status_by_role (SECURITY INVOKER) : chaque rôle ne
--    déplace la commande que sur ses propres étapes, comme ci-dessus.
--    Jamais de retour en arrière.
--
-- Restent libres : l'admin connecté, postgres (SQL Editor), service_role
-- (tableau de bord, Edge Functions) et toutes les fonctions SECURITY DEFINER.
-- Réécrire le même statut ne déclenche aucun contrôle.
--
-- Les deux fonctions DOIVENT rester SECURITY INVOKER : le contrôle final
-- refuse le fichier sinon.
-- ============================================================================


-- ── 1. Garde-fou des colonnes ───────────────────────────────────────────────
create or replace function public.guard_orders_column_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid        uuid;
  v_changed    text[];
  v_allowed    text[] := array[]::text[];
  v_violations text[];
  v_my_drivers uuid[];
begin
  -- Chemins serveur (postgres, service_role, fonctions SECURITY DEFINER).
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  v_uid := auth.uid();

  -- Admins : sans restriction (lecture de son propre profil permise).
  if v_uid is not null and exists (
    select 1 from public.profiles where id = v_uid and is_admin = true
  ) then
    return new;
  end if;

  select array_agg(o.key) into v_changed
  from jsonb_each(to_jsonb(old)) o
  join jsonb_each(to_jsonb(new)) n using (key)
  where o.value is distinct from n.value;

  if v_changed is null then
    return new;
  end if;

  select coalesce(array_agg(d.id), array[]::uuid[]) into v_my_drivers
    from public.drivers d where d.user_id = v_uid;

  -- Client propriétaire de la commande.
  if v_uid is not null and old.user_id = v_uid then
    v_allowed := v_allowed
      || array['status', 'cancellation_reason', 'cancelled_by', 'cancelled_at'];
  end if;

  -- Partenaire propriétaire de la boutique, toute catégorie.
  if v_uid is not null and exists (
    select 1 from public.partners p
    where p.user_id = v_uid
      and p.entity_id::text ~ '^[0-9a-f-]{36}$'
      and (p.entity_id::text::uuid = old.restaurant_id
        or p.entity_id::text::uuid = old.supermarket_id)
  ) then
    v_allowed := v_allowed
      || array['status', 'cancellation_reason', 'cancelled_by', 'cancelled_at'];
    -- Livrer soi-même : seulement une commande qu'aucun livreur ne porte.
    if old.driver_id is null then
      v_allowed := v_allowed || array['self_delivery'];
    end if;
  end if;

  -- Livreur affecté. Se retirer de la course passe par driver_release_order.
  if old.driver_id is not null and old.driver_id = any (v_my_drivers) then
    v_allowed := v_allowed || array['status', 'bill_receipt_url'];
  end if;

  -- Prise de course atomique.
  if old.driver_id is null and new.driver_id is not null
     and new.driver_id = any (v_my_drivers) then
    v_allowed := v_allowed || array['driver_id'];
  end if;

  select array_agg(c) into v_violations
  from unnest(v_changed) c
  where c <> all (v_allowed);

  if v_violations is not null then
    raise exception 'ORDER_COLUMN_SCOPE: column(s) % not allowed for this role', v_violations
      using hint = 'Client apps may only modify the order columns scoped to their role.';
  end if;

  return new;
end;
$$;


-- ── 2. Statuts par rôle ─────────────────────────────────────────────────────
create or replace function public.aa_guard_status_by_role()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid   uuid;
  v_chain constant text[] := array['pending', 'confirmed', 'preparing', 'ready',
                                   'pickedUp', 'onTheWay', 'delivered'];
  v_old   integer;
  v_new   integer;
  v_before_pickup boolean;
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if new.status is not distinct from old.status then
    return new;
  end if;

  v_uid := auth.uid();
  if v_uid is not null and exists (
    select 1 from public.profiles where id = v_uid and is_admin = true
  ) then
    return new;
  end if;

  v_old := array_position(v_chain, old.status);
  v_new := array_position(v_chain, new.status);
  v_before_pickup := old.status in ('pending', 'confirmed', 'preparing', 'ready');

  -- Client : annuler avant la prise en charge ; pour un colis en route,
  -- confirmer que le destinataire l'a reçu.
  if v_uid is not null and old.user_id = v_uid and (
       (new.status = 'cancelled' and v_before_pickup)
    or (new.status = 'delivered' and old.status = 'onTheWay' and old.order_type = 'courier')
  ) then
    return new;
  end if;

  -- Partenaire : avancer, jamais reculer ; annuler avant la prise en charge ;
  -- « livrée » seulement pour une commande qu'il livre lui-même, une fois
  -- partie.
  if v_uid is not null and exists (
       select 1 from public.partners p
        where p.user_id = v_uid
          and p.entity_id::text ~ '^[0-9a-f-]{36}$'
          and (p.entity_id::text::uuid = old.restaurant_id
            or p.entity_id::text::uuid = old.supermarket_id))
     and (
       (new.status = 'cancelled' and v_before_pickup)
    or (new.status in ('confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay') and v_new > v_old)
    or (new.status = 'delivered' and old.status in ('pickedUp', 'onTheWay')
        and coalesce(old.self_delivery, false) and old.driver_id is null)
  ) then
    return new;
  end if;

  -- Livreur affecté : avancer vers récupérée / en route / livrée.
  if v_uid is not null and old.driver_id is not null and exists (
       select 1 from public.drivers d where d.id = old.driver_id and d.user_id = v_uid)
     and new.status in ('pickedUp', 'onTheWay', 'delivered') and v_new > v_old then
    return new;
  end if;

  raise exception 'ORDER_STATUS_SCOPE: % -> % not allowed for this role (order %)',
    old.status, new.status, old.id
    using hint = 'Each app may only move an order along its own steps.';
end;
$$;

drop trigger if exists aa_guard_status_by_role on public.orders;
create trigger aa_guard_status_by_role
before update of status on public.orders
for each row
execute function public.aa_guard_status_by_role();


-- ── Contrôle : si quelque chose manque, tout le fichier est annulé ─────────
do $check$
begin
  if (select prosecdef from pg_proc
       where oid = to_regprocedure('public.guard_orders_column_scope()')) is distinct from false then
    raise exception 'orders_write_guard incomplet : guard_orders_column_scope doit être SECURITY INVOKER';
  end if;
  if (select prosecdef from pg_proc
       where oid = to_regprocedure('public.aa_guard_status_by_role()')) is distinct from false then
    raise exception 'orders_write_guard incomplet : aa_guard_status_by_role doit être SECURITY INVOKER';
  end if;
  if not exists (select 1 from pg_trigger
                  where tgrelid = 'public.orders'::regclass and tgenabled = 'O'
                    and tgname = 'aa_guard_status_by_role') then
    raise exception 'orders_write_guard incomplet : trigger aa_guard_status_by_role absent';
  end if;
  if not exists (select 1 from pg_trigger
                  where tgrelid = 'public.orders'::regclass and tgenabled = 'O'
                    and tgname = 'aa_guard_orders_column_scope') then
    raise exception 'orders_write_guard incomplet : trigger aa_guard_orders_column_scope absent ou désactivé';
  end if;
  -- La version du 29/10 au soir : « livrée » réservée à la livraison par la
  -- boutique, plus de retrait direct du livreur.
  if (select prosrc like '%coalesce(old.self_delivery, false)%' from pg_proc
       where oid = to_regprocedure('public.aa_guard_status_by_role()')) is distinct from true
     or (select prosrc like '%passed_driver_ids%' from pg_proc
          where oid = to_regprocedure('public.guard_orders_column_scope()')) is distinct from false then
    raise exception 'orders_write_guard incomplet : ancienne version des gardes';
  end if;
end
$check$;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : cinq colonnes à true.
select (select not prosecdef from pg_proc
         where oid = to_regprocedure('public.guard_orders_column_scope()')) as colonnes_invoker,
       exists (select 1 from pg_trigger
                where tgrelid = 'public.orders'::regclass and tgenabled = 'O'
                  and tgname = 'aa_guard_status_by_role') as statuts_actifs,
       coalesce((select prosrc like '%coalesce(old.self_delivery, false)%' from pg_proc
                  where oid = to_regprocedure('public.aa_guard_status_by_role()'))
                and (select prosrc not like '%passed_driver_ids%' from pg_proc
                      where oid = to_regprocedure('public.guard_orders_column_scope()')),
                false) as version_finale,
       exists (select 1 from pg_trigger
                where tgrelid = 'public.orders'::regclass and tgenabled = 'O'
                  and tgname = 'aa_guard_delivered_terminal') as garde_livree_appliquee,
       exists (select 1 from pg_indexes
                where schemaname = 'public' and indexname = 'settlements_once_per_order') as lockdown_applique;
