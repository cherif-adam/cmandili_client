-- ============================================================================
-- CMANDILI / Amana — Harnais : 20261028120000_security_lockdown
--
-- SÛR À LANCER EN PRODUCTION : une transaction terminée par ROLLBACK. Les
-- triggers UTILISATEUR de orders sont coupés, sauf celui des règlements que
-- l'on teste (pas de push, pas de dispatch). Aucun appel au Stockage ni à
-- GoTrue : les objets du Stockage sont des lignes insérées puis annulées.
--
-- À lancer d'un bloc, APRÈS 20261028120000. Le résultat est la dernière ligne.
--
-- Ce qui est vérifié, avec l'identité de chaque app :
--   S1  fonctions du cron et des triggers : ni anon ni authenticated ne les
--       exécutent ; service_role et postgres oui
--   S2  get_driver_earnings : le livreur pour lui-même et l'admin oui ; un
--       autre livreur, un client et un visiteur non
--   S3  deliveries : client = ses commandes, partenaire = sa boutique,
--       livreur = les siennes (lecture, écriture, création), admin = tout ;
--       un client ne modifie plus une livraison
--   S4  notifications : personne n'en écrit depuis une app ; chacun lit les
--       siennes
--   S5  order_items : le client dans SA commande oui, un autre non
--   S6  Stockage : le partenaire dépose et réécrit SON image, un autre ne la
--       réécrit pas ; avatars/<id>/ est réservé à cet id ; un nom neuf à la
--       racine de profiles reste permis ; un visiteur ne dépose rien
--   S7  règlements : livrée, re-livrée après un retour en arrière, puis
--       re-livrée encore : prélèvements et subvention une seule fois, soldes
--       bougés une seule fois ; les 7 doublons historiques sont intacts
--   S8  l'index refuse un deuxième prélèvement écrit à la main
-- ============================================================================

begin;

do $test$
declare
  u_c uuid := gen_random_uuid();  -- client (commande O1)
  u_x uuid := gen_random_uuid();  -- autre client (commande O2), joue l'intrus
  u_d uuid := gen_random_uuid();  -- livreur D
  u_e uuid := gen_random_uuid();  -- livreur E
  u_p uuid := gen_random_uuid();  -- partenaire de la boutique V
  u_a uuid := gen_random_uuid();  -- admin
  v_v uuid;                       -- boutique du partenaire
  v_w uuid;                       -- autre boutique
  d_d uuid;
  d_e uuid;
  o1 uuid; o2 uuid; o3 uuid; o4 uuid;
  del1 uuid; del2 uuid;
  n  integer;
  n2 integer;
  r  json;
  ok boolean;
  obj_p text := 'sectest-' || gen_random_uuid()::text || '.jpg';
  res text := '';
begin
  -- ── Jeu d'essai ──────────────────────────────────────────────────────────
  alter table public.orders disable trigger user;
  alter table public.orders enable trigger on_order_delivered_settlements;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'sectest-' || u::text || '@test.invalid', '{}'::jsonb,
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_c, u_x, u_d, u_e, u_p, u_a]) as u;
  update public.profiles set is_admin = (id = u_a), is_blocked = false
   where id = any (array[u_c, u_x, u_d, u_e, u_p, u_a]);

  insert into public.vendors (category, name, is_open) values ('food', 'Boutique Test Sécurité V', true) returning id into v_v;
  insert into public.vendors (category, name, is_open) values ('food', 'Boutique Test Sécurité W', true) returning id into v_w;
  insert into public.partners (user_id, partner_type, entity_id, business_name, phone, address)
  values (u_p, 'restaurant', v_v, 'Boutique Test Sécurité V', '+21655555555', 'Rue test');

  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_d, true, 35.67, 10.10, now(), false, 'Test', 'D', 'Blanc', '111 TU 1111') returning id into d_d;
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_e, true, 35.68, 10.11, now(), false, 'Test', 'E', 'Gris', '222 TU 2222') returning id into d_e;

  insert into public.wallets (user_id, balance, status, blocked_reason)
  values (u_d, 50, 'active', null), (u_p, 50, 'active', null)
  on conflict (user_id) do update set balance = excluded.balance, status = 'active', blocked_reason = null;

  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'onTheWay', 'food', 30, 4.5, 34.5, 'cash', false) returning id into o1;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_x, v_w, d_e, 'onTheWay', 'food', 20, 3.5, 23.5, 'cash', false) returning id into o2;
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng) values (o1, d_d, 'onTheWay', 35.67, 10.10) returning id into del1;
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng) values (o2, d_e, 'onTheWay', 35.68, 10.11) returning id into del2;

  -- ── S1 fonctions fermées ─────────────────────────────────────────────────
  if has_function_privilege('anon', 'public.cancel_stalled_orders(integer)', 'execute')
     or has_function_privilege('authenticated', 'public.cancel_stalled_orders(integer)', 'execute')
     or has_function_privilege('authenticated', 'public.offer_order_to_driver(uuid,uuid,integer,boolean)', 'execute')
     or has_function_privilege('anon', 'public.nearby_online_free_drivers(double precision,double precision,double precision)', 'execute')
     or not has_function_privilege('service_role', 'public.dispatch_driver_for_order(uuid,double precision,integer)', 'execute')
     or not has_function_privilege('postgres', 'public.cancel_stalled_orders(integer)', 'execute') then
    raise exception 'FAIL S1 : droits sur les fonctions';
  end if;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    -- 100 000 000 minutes : même si l'appel passait, aucune vraie commande
    -- ne serait assez ancienne pour être touchée.
    perform public.cancel_stalled_orders(100000000);
    raise exception 'FAIL S1 : un visiteur annule les commandes';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u_x, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    perform public.dispatch_driver_for_order(o1, 7, 30);
    raise exception 'FAIL S1 : un client relance le dispatch';
  exception when insufficient_privilege then null;
  end;
  reset role;
  res := res || 'S1 ok; ';

  -- ── S2 get_driver_earnings ───────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.get_driver_earnings(d_d, now() - interval '1 day', now() + interval '1 day');
  reset role;
  if r is null then raise exception 'FAIL S2 : le livreur ne lit plus ses gains'; end if;
  begin
    set local role authenticated;
    r := public.get_driver_earnings(d_e, now() - interval '1 day', now() + interval '1 day');
    raise exception 'FAIL S2 : un livreur lit les gains d''un autre';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    r := public.get_driver_earnings(d_d, now() - interval '1 day', now() + interval '1 day');
    raise exception 'FAIL S2 : un client lit les gains d''un livreur';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.get_driver_earnings(d_d, now() - interval '1 day', now() + interval '1 day');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    r := public.get_driver_earnings(d_d, now() - interval '1 day', now() + interval '1 day');
    raise exception 'FAIL S2 : un visiteur lit des gains';
  exception when insufficient_privilege then null;
  end;
  reset role;
  res := res || 'S2 ok; ';

  -- ── S3 deliveries ────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.deliveries where id in (del1, del2);
  update public.deliveries set current_lat = 0 where id = del1;
  get diagnostics n2 = row_count;
  reset role;
  if n <> 1 or n2 <> 0 then
    raise exception 'FAIL S3 client : % visible(s), % modifiée(s)', n, n2;
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', u_p, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.deliveries where id = del1;
  select count(*) + n * 10 into n from public.deliveries where id = del2;
  reset role;
  if n <> 10 then raise exception 'FAIL S3 partenaire : % (attendu sa livraison seulement)', n; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.deliveries set current_lat = 35.7, updated_at = now() where id = del1;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL S3 livreur : sa position ne s''écrit plus'; end if;
  update public.deliveries set current_lat = 0 where id = del2;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL S3 livreur : il modifie la livraison d''un autre'; end if;
  select count(*) into n from public.deliveries where id in (del1, del2);
  if n <> 1 then raise exception 'FAIL S3 livreur : % livraisons visibles', n; end if;
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng) values (o1, d_d, 'accepted', 0, 0);
  reset role;
  begin
    set local role authenticated;
    insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng) values (o1, d_e, 'accepted', 0, 0);
    raise exception 'FAIL S3 livreur : il crée une livraison au nom d''un autre';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.deliveries where id in (del1, del2);
  reset role;
  if n <> 2 then raise exception 'FAIL S3 admin : % visible(s)', n; end if;

  -- Un visiteur ne voit rien. Selon la policy évaluée, Postgres répond par
  -- une liste vide ou par un refus (la policy client lit orders, qu'anon ne
  -- peut pas lire) : les deux sont un non.
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    select count(*) into n from public.deliveries where id in (del1, del2);
  exception when insufficient_privilege then n := 0;
  end;
  reset role;
  if n <> 0 then raise exception 'FAIL S3 visiteur : % visible(s)', n; end if;
  res := res || 'S3 ok; ';

  -- ── S4 notifications ─────────────────────────────────────────────────────
  insert into public.notifications (user_id, title, body) values (u_c, 'sectest', 'b');
  perform set_config('request.jwt.claims', json_build_object('sub', u_x, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    insert into public.notifications (user_id, title, body) values (u_c, 'faux', 'message');
    raise exception 'FAIL S4 : un client écrit une notification à un autre';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    insert into public.notifications (user_id, title, body) values (u_c, 'faux', 'message');
    raise exception 'FAIL S4 : un visiteur écrit une notification';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.notifications where user_id = u_c and title = 'sectest';
  reset role;
  if n <> 1 then raise exception 'FAIL S4 : le client ne lit plus ses notifications'; end if;
  res := res || 'S4 ok; ';

  -- ── S5 order_items ───────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.order_items (order_id, price, quantity) values (o1, 10, 1);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', u_x, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    insert into public.order_items (order_id, price, quantity) values (o1, 99, 5);
    raise exception 'FAIL S5 : un client ajoute des articles à la commande d''un autre';
  exception when insufficient_privilege then null;
  end;
  reset role;
  res := res || 'S5 ok; ';

  -- ── S6 Stockage ──────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_p, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into storage.objects (bucket_id, name, owner, owner_id) values ('items', obj_p, u_p, u_p::text);
  update storage.objects set metadata = '{"sectest": 1}'::jsonb where bucket_id = 'items' and name = obj_p;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL S6 : le partenaire ne réécrit plus son image'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', u_x, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update storage.objects set metadata = '{"pirate": 1}'::jsonb where bucket_id = 'items' and name = obj_p;
  get diagnostics n = row_count;
  reset role;
  if n <> 0 then raise exception 'FAIL S6 : un autre réécrit l''image du partenaire'; end if;

  begin
    set local role authenticated;
    insert into storage.objects (bucket_id, name, owner, owner_id)
    values ('profiles', 'avatars/' || u_c::text || '/avatar.jpg', u_x, u_x::text);
    raise exception 'FAIL S6 : un autre occupe le dossier avatar du client';
  exception when insufficient_privilege then null;
  end;
  reset role;
  set local role authenticated;
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values ('profiles', u_x::text || '-' || extract(epoch from now())::bigint || '.jpg', u_x, u_x::text);
  reset role;

  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values ('profiles', 'avatars/' || u_c::text || '/avatar.jpg', u_c, u_c::text);
  update storage.objects set metadata = '{"v": 2}'::jsonb
   where bucket_id = 'profiles' and name = 'avatars/' || u_c::text || '/avatar.jpg';
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL S6 : le client ne réécrit plus son avatar'; end if;

  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  begin
    set local role anon;
    insert into storage.objects (bucket_id, name) values ('items', 'anon-' || gen_random_uuid()::text || '.jpg');
    raise exception 'FAIL S6 : un visiteur dépose un fichier';
  exception when insufficient_privilege then null;
  end;
  reset role;
  res := res || 'S6 ok; ';

  -- ── S7 règlements une seule fois ─────────────────────────────────────────
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'onTheWay', 'food', 30, 4.5, 34.5, 'cash', false) returning id into o3;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery,
                             loyalty_milestone_type, loyalty_discount_amount)
  values (u_c, v_v, d_d, 'onTheWay', 'food', 30, 2.25, 32.25, 'cash', false, 'half', 2.25) returning id into o4;

  update public.orders set status = 'delivered' where id in (o3, o4);
  update public.orders set status = 'onTheWay'  where id in (o3, o4);
  update public.orders set status = 'delivered' where id in (o3, o4);
  update public.orders set status = 'onTheWay'  where id in (o3, o4);
  update public.orders set status = 'delivered' where id in (o3, o4);

  select count(*) into n from public.settlements where related_order_id = o3;
  if n <> 2 then raise exception 'FAIL S7 : % règlements pour une commande livrée trois fois (attendu 2)', n; end if;
  select count(*) into n from public.settlements where related_order_id = o4;
  if n <> 3 then raise exception 'FAIL S7 : % règlements pour la commande fidélité (attendu 3)', n; end if;
  -- Partenaire : 50 - 3.000 - 3.000 ; livreur : 50 - 1.035 - 0.518 + 1.733
  if (select balance from public.wallets where user_id = u_p) <> 44.000
     or (select balance from public.wallets where user_id = u_d) <> 50.180 then
    raise exception 'FAIL S7 : soldes % / % (attendu 44.000 / 50.180)',
      (select balance from public.wallets where user_id = u_p), (select balance from public.wallets where user_id = u_d);
  end if;
  select count(*) into n from public.settlements
   where id = any ('{25c5a2db-7b81-4573-83da-b44a42affc64,230edd79-2766-491c-9dd9-382508175dd5,db2910b3-02a8-4cb2-8a4d-a13ae596b578,8ca9a683-ee8c-452e-99ff-f20cc9a69e38,ba94140f-ee22-41f9-9fe9-1d2d2f65a751,eb416549-642c-4bae-8658-5ae9a5ce1ec3,c0b29bc1-eb18-426a-ac40-899629707caa}'::uuid[]);
  if n <> 7 then raise exception 'FAIL S7 : les doublons historiques ont bougé (%)', n; end if;
  res := res || 'S7 ok; ';

  -- ── S8 l'index tient même sans le trigger ────────────────────────────────
  begin
    insert into public.settlements (user_id, entity_type, amount, type, description, related_order_id, status)
    values (u_d, 'driver', -1.035, 'commission_deduction', 'doublon manuel', o3, 'paid');
    raise exception 'FAIL S8 : un deuxième prélèvement passe';
  exception when unique_violation then null;
  end;
  res := res || 'S8 ok';

  perform set_config('sec.results', res, true);
end
$test$;

select current_setting('sec.results', true) as resultats;

rollback;
