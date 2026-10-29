-- ============================================================================
-- CMANDILI / Amana — Harnais : 20261029120000_orders_write_guard
--
-- SÛR À LANCER EN PRODUCTION : une transaction terminée par ROLLBACK. Les
-- triggers UTILISATEUR de orders sont coupés (pas de push, pas de dispatch),
-- sauf les quatre gardes et le trigger des règlements.
--
-- À lancer d'un bloc, APRÈS 20261028120000, 20260820110000 et
-- 20261029120000. Le résultat est la dernière ligne.
--
-- Chaque écriture est celle du code des apps (même colonnes, mêmes filtres) :
--   W1  client : annuler avant la prise en charge passe ; annuler une
--       commande récupérée, la marquer livrée ou prête est refusé ; changer
--       le total ou les frais est refusé ; colis en route → livré passe
--   W2  partenaire : pending → confirmed → preparing → ready → pickedUp →
--       delivered passe, confirmed → ready aussi ; refus avec motif passe ;
--       livraison par la boutique passe ; reculer, livrer une commande pas
--       partie, changer les frais ou le livreur est refusé
--   W3  livreur : prise de course, reçu de facture, récupérée → en route →
--       livrée passent ; annuler, reculer, changer les frais ou passer la
--       course à un autre est refusé
--   R   se retirer en écrivant soi-même sur la commande (anciennes versions
--       de l'app livreur) est refusé : le retrait passe par
--       driver_release_order (harnais driver_release_order_test.sql)
--   W4  service_role et postgres : inchangés
-- ============================================================================

begin;

do $test$
declare
  u_c uuid := gen_random_uuid();  -- client
  u_p uuid := gen_random_uuid();  -- partenaire de la boutique V
  u_d uuid := gen_random_uuid();  -- livreur D
  u_e uuid := gen_random_uuid();  -- livreur E
  v_v uuid;
  d_d uuid;
  d_e uuid;
  c1 uuid; c2 uuid; c3 uuid; c4 uuid;
  p1 uuid; p2 uuid; p3 uuid; p4 uuid; p5 uuid;
  k1 uuid; k2 uuid; k3 uuid; k4 uuid;
  n   integer;
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
         'wgtest-' || u::text || '@test.invalid', '{}'::jsonb,
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_c, u_p, u_d, u_e]) as u;
  update public.profiles set is_admin = false, is_blocked = false
   where id = any (array[u_c, u_p, u_d, u_e]);

  insert into public.vendors (category, name, is_open) values ('food', 'Boutique Test Écritures', true) returning id into v_v;
  insert into public.partners (user_id, partner_type, entity_id, business_name, phone, address)
  values (u_p, 'restaurant', v_v, 'Boutique Test Écritures', '+21655555555', 'Rue test');
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_d, true, 35.67, 10.10, now(), false, 'Test', 'D', 'Blanc', '444 TU 4444') returning id into d_d;
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_e, true, 35.68, 10.11, now(), false, 'Test', 'E', 'Gris', '555 TU 5555') returning id into d_e;
  insert into public.wallets (user_id, balance, status, blocked_reason)
  values (u_d, 50, 'active', null), (u_e, 50, 'active', null), (u_p, 50, 'active', null)
  on conflict (user_id) do update set balance = excluded.balance, status = 'active', blocked_reason = null;

  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'pending',   'food',    20, 3.5, 23.5, 'cash', false) returning id into c1;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d,  'pickedUp',  'food',    20, 3.5, 23.5, 'cash', false) returning id into c2;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'pending',   'food',    20, 3.5, 23.5, 'cash', false) returning id into c3;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, null, d_d, 'onTheWay',  'courier',  0, 3.5,  3.5, 'cash', false) returning id into c4;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'pending',   'food',    20, 3.5, 23.5, 'cash', false) returning id into p1;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'pending',   'food',    20, 3.5, 23.5, 'cash', false) returning id into p2;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'confirmed', 'food',    20, 3.5, 23.5, 'cash', false) returning id into p3;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'ready',     'food',    20, 3.5, 23.5, 'cash', false) returning id into p4;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'confirmed', 'food',    20, 3.5, 23.5, 'cash', false) returning id into p5;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d,  'ready',     'food',    20, 3.5, 23.5, 'cash', false) returning id into k1;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, null, 'pending',   'food',    20, 3.5, 23.5, 'cash', false) returning id into k2;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery,
                             passed_driver_ids)
  values (u_c, v_v, d_d,  'onTheWay',  'food',    20, 3.5, 23.5, 'cash', false, array[d_e]) returning id into k3;
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d,  'onTheWay',  'food',    20, 3.5, 23.5, 'cash', false) returning id into k4;

  -- ── W1 client ────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.orders
     set status = 'cancelled', cancellation_reason = 'Changement d''avis', cancelled_by = 'customer', cancelled_at = now()
   where id = c1 and user_id = u_c and status in ('pending', 'confirmed', 'preparing', 'ready');
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL W1 : le client n''annule plus une commande en attente'; end if;

  foreach st in array array['c2:cancelled', 'c3:delivered', 'c3:ready'] loop
    begin
      set local role authenticated;
      update public.orders set status = split_part(st, ':', 2)
       where id = case split_part(st, ':', 1) when 'c2' then c2 else c3 end;
      raise exception 'FAIL W1 : le client passe % à %', split_part(st, ':', 1), split_part(st, ':', 2);
    exception when raise_exception then
      get stacked diagnostics msg = message_text;
      if msg not like 'ORDER_STATUS_SCOPE%' then raise; end if;
    end;
    reset role;
  end loop;

  begin
    set local role authenticated;
    update public.orders set total = 0.001, delivery_fee = 0 where id = c3;
    raise exception 'FAIL W1 : le client change le total de sa commande';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;

  set local role authenticated;
  update public.orders set status = 'delivered' where id = c4;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL W1 : l''expéditeur ne confirme plus la remise du colis'; end if;
  res := res || 'W1 ok; ';

  -- ── W2 partenaire ────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_p, 'role', 'authenticated')::text, true);
  set local role authenticated;
  foreach st in array array['confirmed', 'preparing', 'ready', 'pickedUp', 'delivered'] loop
    update public.orders set status = st where id = p1;
    get diagnostics n = row_count;
    if n <> 1 then reset role; raise exception 'FAIL W2 : le partenaire ne passe plus p1 à %', st; end if;
  end loop;
  update public.orders set status = 'ready' where id = p5;
  get diagnostics n = row_count;
  if n <> 1 then reset role; raise exception 'FAIL W2 : confirmed → ready (sans préparation) refusé'; end if;
  update public.orders
     set status = 'cancelled', cancellation_reason = 'Rupture de stock', cancelled_by = 'partner', cancelled_at = now()
   where id = p2 and status in ('pending', 'confirmed', 'preparing', 'ready');
  get diagnostics n = row_count;
  if n <> 1 then reset role; raise exception 'FAIL W2 : le partenaire ne refuse plus une commande'; end if;
  update public.orders set self_delivery = true, status = 'onTheWay' where id = p3;
  update public.orders set status = 'delivered' where id = p3;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL W2 : la livraison par la boutique ne passe plus'; end if;

  foreach st in array array['pending', 'delivered'] loop
    begin
      set local role authenticated;
      update public.orders set status = st where id = p4;
      raise exception 'FAIL W2 : le partenaire passe une commande prête à %', st;
    exception when raise_exception then
      get stacked diagnostics msg = message_text;
      if msg not like 'ORDER_STATUS_SCOPE%' then raise; end if;
    end;
    reset role;
  end loop;
  begin
    set local role authenticated;
    update public.orders set delivery_fee = 0 where id = p4;
    raise exception 'FAIL W2 : le partenaire change les frais';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;
  begin
    set local role authenticated;
    update public.orders set driver_id = d_e where id = p4;
    raise exception 'FAIL W2 : le partenaire choisit le livreur';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;
  res := res || 'W2 ok; ';

  -- ── W3 livreur ───────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.orders set bill_receipt_url = 'wgtest/receipt.jpg' where id = k1;
  get diagnostics n = row_count;
  if n <> 1 then reset role; raise exception 'FAIL W3 : reçu de facture refusé'; end if;
  foreach st in array array['pickedUp', 'onTheWay', 'delivered'] loop
    update public.orders set status = st where id = k1;
    get diagnostics n = row_count;
    if n <> 1 then reset role; raise exception 'FAIL W3 : le livreur ne passe plus k1 à %', st; end if;
  end loop;
  update public.orders set driver_id = d_d where id = k2 and driver_id is null;
  get diagnostics n = row_count;
  if n <> 1 then reset role; raise exception 'FAIL W3 : prise de course refusée'; end if;
  update public.orders set status = 'pickedUp' where id = k2;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL W3 : récupérée avant « prête » refusée'; end if;

  foreach st in array array['cancelled', 'pickedUp'] loop
    begin
      set local role authenticated;
      update public.orders set status = st where id = k4;
      raise exception 'FAIL W3 : le livreur passe une commande en route à %', st;
    exception when raise_exception then
      get stacked diagnostics msg = message_text;
      if msg not like 'ORDER_STATUS_SCOPE%' then raise; end if;
    end;
    reset role;
  end loop;
  begin
    set local role authenticated;
    update public.orders set delivery_fee = 0 where id = k4;
    raise exception 'FAIL W3 : le livreur change les frais';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;
  begin
    set local role authenticated;
    update public.orders set driver_id = d_e where id = k4;
    raise exception 'FAIL W3 : le livreur passe la course à un autre';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;
  res := res || 'W3 ok; ';

  -- ── R retrait écrit directement sur la commande (anciennes versions) ─────
  begin
    set local role authenticated;
    update public.orders
       set driver_id = null, assigned_driver_id = null, status = 'ready', passed_driver_ids = array[d_e, d_d]
     where id = k3 and driver_id = d_d;
    raise exception 'FAIL R : un livreur se retire en écrivant lui-même sur la commande';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'ORDER_COLUMN_SCOPE%' then raise; end if;
  end;
  reset role;
  res := res || 'R ok; ';

  -- ── W4 chemins serveur ───────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  set local role service_role;
  update public.orders set total = 0.5, delivery_fee = 0 where id = c3;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL W4 : service_role bloqué'; end if;
  perform set_config('request.jwt.claims', '', true);
  update public.orders set status = 'pending' where id = p4;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL W4 : postgres bloqué'; end if;
  res := res || 'W4 ok';

  perform set_config('wg.results', res, true);
end
$test$;

select current_setting('wg.results', true) as resultats;

rollback;
