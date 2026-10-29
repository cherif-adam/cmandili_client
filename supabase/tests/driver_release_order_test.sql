-- ============================================================================
-- CMANDILI / Amana — Harnais : 20261029130000_driver_release_order
--
-- SÛR À LANCER EN PRODUCTION : une transaction terminée par ROLLBACK. Les
-- triggers UTILISATEUR de orders sont coupés (pas de push), sauf les gardes et
-- le trigger des règlements. Les offres que la cascade envoie (net.http_post)
-- sont annulées avec le reste : rien ne part.
--
-- La boutique et les livreurs de test sont placés au milieu du Sahara
-- (30° N, 9° E) : aucun vrai livreur n'est dans le rayon, la cascade ne peut
-- choisir que le livreur de test E.
--
-- À lancer d'un bloc, APRÈS 20261029130000. Le résultat est la dernière ligne.
--
--   R1  après la prise en charge : la commande redevient 'ready', sans
--       livreur, offerte au plus proche qui ne l'a pas refusée (E) ; la
--       livraison du livreur est annulée ; une demande « Trajet partiel » est
--       ouverte pour l'admin ; aucun règlement, aucun solde ne bouge
--   R2  commande prête : elle reste prête et repart dans la cascade
--   R3  commande en préparation : elle garde son statut, pas d'offre
--   R4  la commande d'un autre, ou une commande déjà reprise : 'not_assigned'
--   R5  commande livrée, motif vide : refusés
--   R6  un client, un visiteur : refusés
--   R7  plus aucun livreur disponible : le partenaire est prévenu
-- ============================================================================

begin;

do $test$
declare
  u_c uuid := gen_random_uuid();  -- client
  u_p uuid := gen_random_uuid();  -- partenaire de la boutique V
  u_d uuid := gen_random_uuid();  -- livreur D, qui se retire
  u_e uuid := gen_random_uuid();  -- livreur E, le suivant
  v_v uuid;
  d_d uuid;
  d_e uuid;
  k1 uuid; k2 uuid; k3 uuid; k4 uuid; k5 uuid; k6 uuid;
  del1 uuid;
  o   public.orders%rowtype;
  st  text;
  msg text;
  t   name;
  res text := '';
begin
  -- ── Jeu d'essai ──────────────────────────────────────────────────────────
  alter table public.orders disable trigger user;
  for t in select tgname from pg_trigger
            where tgrelid = 'public.orders'::regclass
              and tgname in ('aa_guard_cancelled_terminal', 'aa_guard_delivered_terminal',
                             'aa_guard_orders_column_scope', 'aa_guard_status_by_role',
                             'on_order_delivered_settlements')
  loop
    execute format('alter table public.orders enable trigger %I', t);
  end loop;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'reltest-' || u::text || '@test.invalid', '{}'::jsonb,
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_c, u_p, u_d, u_e]) as u;
  update public.profiles set is_admin = false, is_blocked = false
   where id = any (array[u_c, u_p, u_d, u_e]);

  insert into public.vendors (category, name, is_open, latitude, longitude)
  values ('food', 'Boutique Test Retrait', true, 30.0, 9.0) returning id into v_v;
  insert into public.partners (user_id, partner_type, entity_id, business_name, phone, address)
  values (u_p, 'restaurant', v_v, 'Boutique Test Retrait', '+21655555555', 'Rue test');
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_d, true, 30.001, 9.001, now(), false, 'Test', 'D', 'Blanc', '666 TU 6666') returning id into d_d;
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_e, true, 30.002, 9.002, now(), false, 'Test', 'E', 'Gris', '777 TU 7777') returning id into d_e;
  insert into public.wallets (user_id, balance, status, blocked_reason)
  values (u_d, 50, 'active', null), (u_e, 50, 'active', null), (u_p, 50, 'active', null)
  on conflict (user_id) do update set balance = excluded.balance, status = 'active', blocked_reason = null;

  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'onTheWay',  'food', 20, 4.5, 24.5, 'cash', false) returning id into k1;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'ready',     'food', 20, 4.5, 24.5, 'cash', false) returning id into k2;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'preparing', 'food', 20, 4.5, 24.5, 'cash', false) returning id into k3;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_e, 'onTheWay',  'food', 20, 4.5, 24.5, 'cash', false) returning id into k4;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'delivered', 'food', 20, 4.5, 24.5, 'cash', false) returning id into k5;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery,
                             passed_driver_ids)
  values (u_c, v_v, d_d, 'pickedUp',  'food', 20, 4.5, 24.5, 'cash', false, array[d_e]) returning id into k6;
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng)
  values (k1, d_d, 'onTheWay', 30.001, 9.001) returning id into del1;

  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);

  -- ── R1 après la prise en charge ──────────────────────────────────────────
  set local role authenticated;
  st := public.driver_release_order(k1, 'Panne / accident');
  reset role;
  if st is distinct from 'released' then raise exception 'FAIL R1 : %', st; end if;
  select * into o from public.orders where id = k1;
  if o.driver_id is not null or o.status <> 'ready' or not (d_d = any (o.passed_driver_ids))
     or o.assigned_driver_id is distinct from d_e or o.assignment_expires_at <= now()
     or o.no_driver_notified_at is not null then
    raise exception 'FAIL R1 : livreur=% statut=% offerte à=% refus=%',
      o.driver_id, o.status, o.assigned_driver_id, o.passed_driver_ids;
  end if;
  if (select status from public.deliveries where id = del1) <> 'cancelled' then
    raise exception 'FAIL R1 : la livraison du livreur n''est pas annulée';
  end if;
  if (select count(*) from public.support_tickets
       where user_id = u_d and subject = 'Trajet partiel #' || upper(substring(k1::text, 1, 8))) <> 1 then
    raise exception 'FAIL R1 : pas de demande « Trajet partiel » pour l''admin';
  end if;
  if exists (select 1 from public.settlements where related_order_id = k1)
     or (select balance from public.wallets where user_id = u_d) <> 50 then
    raise exception 'FAIL R1 : un règlement a été écrit ou un solde a bougé';
  end if;
  res := res || 'R1 ok; ';

  -- ── R2 commande prête ────────────────────────────────────────────────────
  set local role authenticated;
  st := public.driver_release_order(k2, 'Trop loin / je ne peux pas livrer');
  reset role;
  select * into o from public.orders where id = k2;
  if st is distinct from 'released' or o.driver_id is not null or o.status <> 'ready'
     or o.assigned_driver_id is distinct from d_e then
    raise exception 'FAIL R2 : % statut=% offerte à=%', st, o.status, o.assigned_driver_id;
  end if;
  if exists (select 1 from public.support_tickets
              where subject = 'Trajet partiel #' || upper(substring(k2::text, 1, 8))) then
    raise exception 'FAIL R2 : demande de trajet ouverte avant la prise en charge';
  end if;
  res := res || 'R2 ok; ';

  -- ── R3 commande en préparation ───────────────────────────────────────────
  set local role authenticated;
  st := public.driver_release_order(k3, 'Urgence personnelle');
  reset role;
  select * into o from public.orders where id = k3;
  if st is distinct from 'released' or o.driver_id is not null or o.status <> 'preparing'
     or o.assigned_driver_id is not null or not (d_d = any (o.passed_driver_ids)) then
    raise exception 'FAIL R3 : % statut=% offerte à=%', st, o.status, o.assigned_driver_id;
  end if;
  res := res || 'R3 ok; ';

  -- ── R4 pas (ou plus) sa course ───────────────────────────────────────────
  set local role authenticated;
  st := public.driver_release_order(k4, 'Autre');
  reset role;
  if st is distinct from 'not_assigned' or (select driver_id from public.orders where id = k4) <> d_e then
    raise exception 'FAIL R4 : la course d''un autre (%)', st;
  end if;
  set local role authenticated;
  st := public.driver_release_order(k1, 'Autre');
  reset role;
  if st is distinct from 'not_assigned' then raise exception 'FAIL R4 : second retrait (%)', st; end if;
  res := res || 'R4 ok; ';

  -- ── R5 commande livrée, motif vide ───────────────────────────────────────
  begin
    set local role authenticated;
    st := public.driver_release_order(k5, 'Autre');
    raise exception 'FAIL R5 : retrait d''une commande livrée';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg <> 'Cette commande est déjà terminée' then raise; end if;
  end;
  reset role;
  begin
    set local role authenticated;
    st := public.driver_release_order(k6, '   ');
    raise exception 'FAIL R5 : retrait sans motif';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg <> 'Un motif est obligatoire' then raise; end if;
  end;
  reset role;
  res := res || 'R5 ok; ';

  -- ── R6 client, visiteur ──────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    st := public.driver_release_order(k6, 'Autre');
    raise exception 'FAIL R6 : un client retire le livreur';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'Seul un livreur%' then raise; end if;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    st := public.driver_release_order(k6, 'Autre');
    raise exception 'FAIL R6 : un visiteur appelle le retrait';
  exception when insufficient_privilege then null;
  end;
  reset role;
  res := res || 'R6 ok; ';

  -- ── R7 plus aucun livreur : le partenaire est prévenu ───────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  st := public.driver_release_order(k6, 'Problème de véhicule');
  reset role;
  select * into o from public.orders where id = k6;
  if st is distinct from 'released' or o.status <> 'ready' or o.assigned_driver_id is not null
     or o.no_driver_notified_at is null then
    raise exception 'FAIL R7 : % offerte à=% prévenu=%', st, o.assigned_driver_id, o.no_driver_notified_at;
  end if;
  res := res || 'R7 ok';

  perform set_config('rel.results', res, true);
end
$test$;

select current_setting('rel.results', true) as resultats;

rollback;
