-- ============================================================================
-- CMANDILI / Amana — Fermer ce que n'importe qui pouvait faire sans en avoir le droit
--
-- NON EXÉCUTÉE. À lancer dans le SQL Editor du dashboard (les policies de
-- storage.objects y ont été créées), après 20261026120000.
--
-- CONSTAT (audit du 28/10/2026, SELECT sur le live) :
--   1. Fonctions SECURITY DEFINER exécutables par anon ET authenticated, sans
--      contrôle d'identité : cancel_stalled_orders(0) annulait toutes les
--      commandes pas encore récupérées ; dispatch_driver_for_order,
--      offer_order_to_driver et notify_partner_no_drivers relançaient des
--      commandes ; les tâches du cron pouvaient être déclenchées par tous.
--   2. get_driver_earnings donnait les gains de n'importe quel livreur, et
--      nearby_online_free_drivers les livreurs en ligne avec leur distance,
--      à n'importe qui, même sans compte.
--   3. deliveries : deliveries_rw (ALL) et deliveries_select ouvraient toutes
--      les livraisons, positions GPS comprises, en lecture ET en écriture à
--      tout compte connecté.
--   4. notifications : notifications_insert (CHECK true) laissait même un
--      visiteur sans compte écrire une notification à n'importe qui.
--   5. order_items : order_items_insert laissait tout compte connecté ajouter
--      des articles à la commande d'un autre.
--   6. Stockage : tout compte connecté pouvait ÉCRASER n'importe quelle image
--      de items, profiles, menu-images et avatars, et occuper le dossier
--      avatars/<id d'un autre>/ avant lui.
--   7. settlements : 3 commandes ont reçu leurs règlements deux fois. Sur le
--      live, une commande peut quitter 'delivered' puis y revenir
--      (20260820110000_guard_delivered_terminal n'y est pas appliquée) ; à
--      chaque retour, generate_settlements_on_delivery écrivait à nouveau.
--
-- CE QUI NE CHANGE PAS POUR LES APPS (code relu le 28/10) :
--   • aucune app n'appelle les fonctions fermées. Leurs appelants sont des
--     fonctions SECURITY DEFINER (pass_order_offer, triggers ghost,
--     rotate_expired_offers, dispatch_driver_for_order), le cron (rôle
--     postgres) et l'Edge Function push-on-order-status (clé service_role) :
--     tous gardent le droit ;
--   • l'app livreur appelle get_driver_earnings avec SON id : toujours permis ;
--   • livraisons : le livreur lit et écrit les siennes, le client lit celles
--     de ses commandes (déjà couverts par les policies gardées) ; le
--     partenaire lit celles de sa boutique (son suivi les lisait grâce à la
--     policy trop large : il reçoit la sienne ici) ;
--   • aucune app n'insère de notification (les triggers sont SECURITY
--     DEFINER, l'admin passe par service_role) ; le client insère les
--     articles de SES commandes (policy « Users can insert order items ») ;
--   • les apps déposent toujours une image sous un nom neuf (uuid ou
--     horodatage) ; seul l'avatar client est réécrit, à avatars/<son id>/,
--     par lui-même : permis.
--
-- Rejouable.
-- ============================================================================


-- ── 1. Fonctions du cron et des déclencheurs : plus d'appel direct ─────────
-- Supabase accorde EXECUTE à anon et authenticated sur toute nouvelle
-- fonction du schéma public : il faut les nommer, en plus de public.

revoke execute on function public.cancel_stalled_orders(integer)             from public, anon, authenticated;
revoke execute on function public.alert_stalled_deliveries(integer)          from public, anon, authenticated;
revoke execute on function public.rotate_expired_offers()                    from public, anon, authenticated;
revoke execute on function public.escalate_parcel_broadcast_tier()           from public, anon, authenticated;
revoke execute on function public.dispatch_driver_for_order(uuid, double precision, integer) from public, anon, authenticated;
revoke execute on function public.offer_order_to_driver(uuid, uuid, integer, boolean)        from public, anon, authenticated;
revoke execute on function public.notify_partner_no_drivers(uuid)            from public, anon, authenticated;
revoke execute on function public.nearby_online_free_drivers(double precision, double precision, double precision) from public, anon, authenticated;

grant execute on function public.cancel_stalled_orders(integer)             to service_role;
grant execute on function public.alert_stalled_deliveries(integer)          to service_role;
grant execute on function public.rotate_expired_offers()                    to service_role;
grant execute on function public.escalate_parcel_broadcast_tier()           to service_role;
grant execute on function public.dispatch_driver_for_order(uuid, double precision, integer) to service_role;
grant execute on function public.offer_order_to_driver(uuid, uuid, integer, boolean)        to service_role;
grant execute on function public.notify_partner_no_drivers(uuid)            to service_role;
grant execute on function public.nearby_online_free_drivers(double precision, double precision, double precision) to service_role;


-- ── 2. get_driver_earnings : le livreur lui-même, ou un admin ──────────────
-- Même calcul qu'avant ; seul le contrôle d'identité s'ajoute. Le
-- service_role (pas d'auth.uid()) n'est pas concerné.

create or replace function public.get_driver_earnings(
  p_driver_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone
)
returns json
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_total double precision;
  v_count integer;
begin
  if auth.uid() is not null
     and not exists (select 1 from public.drivers d where d.id = p_driver_id and d.user_id = auth.uid())
     and not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin is true) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select coalesce(sum(o.delivery_fee), 0), count(*)
    into v_total, v_count
    from public.orders o
   where o.driver_id = p_driver_id
     and o.status = 'delivered'
     and o.created_at >= p_start_date
     and o.created_at <= p_end_date;

  return json_build_object('total', v_total, 'count', v_count);
end;
$fn$;

revoke execute on function public.get_driver_earnings(uuid, timestamp with time zone, timestamp with time zone) from public, anon;
grant execute on function public.get_driver_earnings(uuid, timestamp with time zone, timestamp with time zone) to authenticated, service_role;


-- ── 3. deliveries : chacun les siennes ─────────────────────────────────────
-- Restent : « Drivers can insert / update / view own deliveries » et
-- « Users can view deliveries for their orders ».

drop policy if exists deliveries_rw     on public.deliveries;
drop policy if exists deliveries_select on public.deliveries;

drop policy if exists deliveries_partner_select on public.deliveries;
create policy deliveries_partner_select
  on public.deliveries for select
  to authenticated
  using (exists (select 1 from public.orders o
                  where o.id = deliveries.order_id
                    and (public.owns_vendor(o.restaurant_id) or public.owns_vendor(o.supermarket_id))));

drop policy if exists deliveries_admin_select on public.deliveries;
create policy deliveries_admin_select
  on public.deliveries for select
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_admin is true));


-- ── 4. notifications : plus aucune insertion depuis les apps ───────────────

drop policy if exists notifications_insert on public.notifications;
drop policy if exists "System can insert notifications" on public.notifications;


-- ── 5. order_items : seulement dans ses propres commandes ──────────────────

drop policy if exists order_items_insert on public.order_items;


-- ── 6. Stockage : on ne réécrit que ses fichiers ───────────────────────────
-- Lecture publique inchangée. Une seule policy d'écriture par opération pour
-- ces quatre buckets ; dans profiles, le dossier avatars/<id>/ n'appartient
-- qu'à cet id (sinon on pourrait occuper le chemin de l'avatar d'un autre).

drop policy if exists "Users can update items storage"   on storage.objects;
drop policy if exists "Users can update own avatars"     on storage.objects;
drop policy if exists "Users can update profiles storage" on storage.objects;
drop policy if exists storage_update                     on storage.objects;
drop policy if exists "Authenticated users can upload avatars"   on storage.objects;
drop policy if exists "Authenticated users can upload items"     on storage.objects;
drop policy if exists "Authenticated users can upload to profiles" on storage.objects;
drop policy if exists storage_upload                     on storage.objects;

drop policy if exists media_insert_own on storage.objects;
create policy media_insert_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id in ('items', 'profiles', 'menu-images', 'avatars')
    and (bucket_id <> 'profiles'
         or coalesce((storage.foldername(name))[1], '') <> 'avatars'
         or (storage.foldername(name))[2] = (select auth.uid())::text)
  );

drop policy if exists media_update_own on storage.objects;
create policy media_update_own
  on storage.objects for update
  to authenticated
  using (
    bucket_id in ('items', 'profiles', 'menu-images', 'avatars')
    and owner_id = (select auth.uid())::text
  )
  with check (
    bucket_id in ('items', 'profiles', 'menu-images', 'avatars')
    and owner_id = (select auth.uid())::text
    and (bucket_id <> 'profiles'
         or coalesce((storage.foldername(name))[1], '') <> 'avatars'
         or (storage.foldername(name))[2] = (select auth.uid())::text)
  );


-- ── 7. settlements : une seule fois par commande ───────────────────────────
-- Un règlement automatique par (commande, compte, rôle, type). Les 7 copies
-- déjà écrites deux fois (09/26, 10/09, 10/11) sont laissées hors de l'index :
-- l'historique ne se réécrit pas, il se corrige par écriture (voir la
-- proposition de correction séparée).

create unique index if not exists settlements_once_per_order
  on public.settlements (related_order_id, user_id, entity_type, type)
  where related_order_id is not null
    and type in ('commission_deduction', 'loyalty_subsidy')
    and id <> all ('{25c5a2db-7b81-4573-83da-b44a42affc64,
                    230edd79-2766-491c-9dd9-382508175dd5,
                    db2910b3-02a8-4cb2-8a4d-a13ae596b578,
                    8ca9a683-ee8c-452e-99ff-f20cc9a69e38,
                    ba94140f-ee22-41f9-9fe9-1d2d2f65a751,
                    eb416549-642c-4bae-8658-5ae9a5ce1ec3,
                    c0b29bc1-eb18-426a-ac40-899629707caa}'::uuid[]);

-- Identique à la version du live, plus ON CONFLICT DO NOTHING sur les trois
-- écritures : un retour à 'delivered' ne prélève ni ne verse rien de plus.
create or replace function public.generate_settlements_on_delivery()
returns trigger
language plpgsql
security definer
as $fn$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission     NUMERIC(12,3);
  v_partner_user_id       UUID;
  v_driver_user_id        UUID;
  v_restaurant_rate       NUMERIC(5,4);
  v_driver_rate           NUMERIC(5,4);
  v_subsidy               NUMERIC(12,3);
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' AND NEW.payment_method = 'cash' THEN

    -- Live rates from global_settings (fall back to defaults if rows missing)
    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_restaurant_commission_rate'),
        0.10
    ) INTO v_restaurant_rate;

    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_driver_commission_rate'),
        0.23
    ) INTO v_driver_rate;

    -- Resolve partner user_id (entity_id::text works for uuid or text column)
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- Resolve driver's auth user_id (orders.driver_id = drivers.id, and
    -- settlements.user_id FKs to auth.users)
    IF NEW.driver_id IS NOT NULL THEN
      SELECT user_id INTO v_driver_user_id
        FROM public.drivers WHERE id = NEW.driver_id LIMIT 1;
    END IF;

    -- Commission cuts
    v_restaurant_commission := NEW.subtotal * v_restaurant_rate;
    IF NEW.self_delivery THEN
      v_driver_commission := 0;
    ELSE
      v_driver_commission := NEW.delivery_fee * v_driver_rate;
    END IF;

    -- Stamp the order with the platform's cuts (non-retroactive)
    UPDATE public.orders
       SET platform_fee   = v_restaurant_commission,
           driver_fee_cut = v_driver_commission
     WHERE id = NEW.id;

    -- Partner: deduct the 10% commission from the restaurant's prepaid balance.
    -- (The partner still receives the food cash directly via the driver; the
    --  wallet only tracks the commission the platform takes.)
    IF v_partner_user_id IS NOT NULL AND v_restaurant_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_partner_user_id,
        'restaurant',
        -v_restaurant_commission,
        'commission_deduction',
        'Commission commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    -- Driver: deduct the delivery-fee commission from the driver's prepaid
    -- balance (driver keeps the delivery cash; platform takes its cut here).
    IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery
       AND v_driver_user_id IS NOT NULL AND v_driver_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_driver_user_id,
        'driver',
        -v_driver_commission,
        'commission_deduction',
        'Commission livraison #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    -- Driver: loyalty subsidy. NEW.loyalty_discount_amount is what the
    -- client was NOT charged (stamped at order creation). Net of the same
    -- commission rate the driver already paid above, so cash collected -
    -- commission + subsidy == a normal full-price delivery's net earning.
    IF NEW.loyalty_milestone_type IS NOT NULL AND NEW.driver_id IS NOT NULL
       AND NOT NEW.self_delivery AND v_driver_user_id IS NOT NULL THEN
      v_subsidy := NEW.loyalty_discount_amount * (1 - v_driver_rate);
      IF v_subsidy > 0 THEN
        INSERT INTO public.settlements
          (user_id, entity_type, amount, type, description, related_order_id, status)
        VALUES (
          v_driver_user_id,
          'driver',
          v_subsidy,
          'loyalty_subsidy',
          'Subvention fidélité (' ||
            CASE NEW.loyalty_milestone_type WHEN 'free' THEN 'livraison gratuite' ELSE '-50% livraison' END ||
            ') #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
          NEW.id,
          'paid'
        )
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

  END IF;
  RETURN NEW;
END;
$fn$;


-- ── Contrôle : la migration s'annule si l'état final n'est pas le bon ──────

do $$
declare
  v_fn  text;
  v_bad text := '';
begin
  foreach v_fn in array array[
    'public.cancel_stalled_orders(integer)', 'public.alert_stalled_deliveries(integer)',
    'public.rotate_expired_offers()', 'public.escalate_parcel_broadcast_tier()',
    'public.dispatch_driver_for_order(uuid,double precision,integer)',
    'public.offer_order_to_driver(uuid,uuid,integer,boolean)',
    'public.notify_partner_no_drivers(uuid)',
    'public.nearby_online_free_drivers(double precision,double precision,double precision)']
  loop
    if has_function_privilege('anon', v_fn, 'execute') or has_function_privilege('authenticated', v_fn, 'execute')
       or not has_function_privilege('service_role', v_fn, 'execute') then
      v_bad := v_bad || v_fn || ' ';
    end if;
  end loop;
  if has_function_privilege('anon', 'public.get_driver_earnings(uuid,timestamp with time zone,timestamp with time zone)', 'execute')
     or not has_function_privilege('authenticated', 'public.get_driver_earnings(uuid,timestamp with time zone,timestamp with time zone)', 'execute') then
    v_bad := v_bad || 'get_driver_earnings ';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public'
              and (tablename, policyname) in (('deliveries', 'deliveries_rw'), ('deliveries', 'deliveries_select'),
                                              ('notifications', 'notifications_insert'), ('notifications', 'System can insert notifications'),
                                              ('order_items', 'order_items_insert'))) then
    v_bad := v_bad || 'policies ';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd in ('INSERT', 'UPDATE')
              and policyname not in ('media_insert_own', 'media_update_own')
              and coalesce(qual, with_check) ~ '''(items|profiles|menu-images|avatars)''') then
    v_bad := v_bad || 'storage ';
  end if;
  if to_regclass('public.settlements_once_per_order') is null
     or (select count(*) from regexp_matches((select prosrc from pg_proc where oid = 'public.generate_settlements_on_delivery'::regproc),
                                             'ON CONFLICT DO NOTHING', 'g')) <> 3 then
    v_bad := v_bad || 'settlements ';
  end if;
  if v_bad <> '' then
    raise exception 'security_lockdown incomplet : %', v_bad;
  end if;
end
$$;


-- ── Vérification (à lire après l'exécution) ────────────────────────────────
-- Attendu : une ligne, toutes les colonnes à true.
select
  not has_function_privilege('anon', 'public.cancel_stalled_orders(integer)', 'execute')
    and not has_function_privilege('authenticated', 'public.cancel_stalled_orders(integer)', 'execute')
    and not has_function_privilege('anon', 'public.nearby_online_free_drivers(double precision,double precision,double precision)', 'execute')
    and not has_function_privilege('authenticated', 'public.dispatch_driver_for_order(uuid,double precision,integer)', 'execute')
    as fonctions_fermees,
  position('forbidden' in (select prosrc from pg_proc where oid = 'public.get_driver_earnings'::regproc)) > 0
    and not has_function_privilege('anon', 'public.get_driver_earnings(uuid,timestamp with time zone,timestamp with time zone)', 'execute')
    as gains_proteges,
  not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deliveries' and policyname in ('deliveries_rw', 'deliveries_select'))
    and exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deliveries' and policyname = 'deliveries_partner_select')
    as livraisons_ok,
  not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'notifications' and cmd = 'INSERT')
    as notifications_ok,
  not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'order_items' and policyname = 'order_items_insert')
    as articles_ok,
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname in ('media_insert_own', 'media_update_own')) = 2
    as stockage_ok,
  to_regclass('public.settlements_once_per_order') is not null
    as reglements_ok;
