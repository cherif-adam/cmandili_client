-- ============================================================================
-- CMANDILI / Amana — Harnais : 20260820110000_guard_delivered_terminal
--
-- SÛR À LANCER EN PRODUCTION : une transaction terminée par ROLLBACK. Les
-- triggers UTILISATEUR de orders sont coupés (pas de push, pas de dispatch),
-- sauf les trois gardes et le trigger des règlements, que l'on teste.
--
-- À lancer d'un bloc, APRÈS 20261028120000 et 20260820110000. Le résultat
-- est la dernière ligne.
--
-- Chaque app est jouée avec son identité, comme ses écrans le font :
--   G1  livreur : ready → pickedUp → onTheWay → delivered ; règlements
--       écrits une fois
--   G2  livreur sur un écran pas à jour : delivered → onTheWay, pickedUp ou
--       ready (« je ne peux pas livrer ») refusés ; réenregistrer
--       'delivered' passe, sans nouveau règlement
--   G3  client : annuler une commande livrée est refusé ; confirmer la
--       réception et annuler une commande en attente passent
--   G4  partenaire : pending → confirmed → preparing → ready → livraison par
--       la boutique → delivered passe ; revenir ensuite à ready est refusé
--   G5  correction à la main dans le SQL Editor (postgres) : sort une
--       commande de 'delivered' et l'y remet ; ni règlement ni solde ne
--       bougent (20261028120000)
--   G6  service_role (tableau de bord admin, Edge Functions) : inchangé,
--       toujours sans double paiement
--   G7  la garde 'cancelled' existante marche toujours
--
-- Pas de cas « admin connecté » : orders n'a pas de policy de lecture admin,
-- le tableau de bord passe par service_role (lib/supabase-admin.ts).
-- ============================================================================

begin;

do $test$
declare
  u_c uuid := gen_random_uuid();  -- client
  u_d uuid := gen_random_uuid();  -- livreur
  u_p uuid := gen_random_uuid();  -- partenaire de la boutique V
  v_v uuid;
  d_d uuid;
  o1 uuid; o2 uuid; o3 uuid;
  n  integer;
  n3 integer;
  st text;
  msg text;
  t  name;
  bal_p numeric;
  bal_d numeric;
  res text := '';
begin
  -- ── Jeu d'essai ──────────────────────────────────────────────────────────
  alter table public.orders disable trigger user;
  for t in select tgname from pg_trigger
            where tgrelid = 'public.orders'::regclass
              and tgname in ('aa_guard_delivered_terminal', 'aa_guard_cancelled_terminal',
                             'aa_guard_orders_column_scope', 'aa_guard_status_by_role',
                             'on_order_delivered_settlements')
  loop
    execute format('alter table public.orders enable trigger %I', t);
  end loop;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'guardtest-' || u::text || '@test.invalid', '{}'::jsonb,
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_c, u_d, u_p]) as u;
  update public.profiles set is_admin = false, is_blocked = false
   where id = any (array[u_c, u_d, u_p]);

  insert into public.vendors (category, name, is_open) values ('food', 'Boutique Test Garde', true) returning id into v_v;
  insert into public.partners (user_id, partner_type, entity_id, business_name, phone, address)
  values (u_p, 'restaurant', v_v, 'Boutique Test Garde', '+21655555555', 'Rue test');
  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_d, true, 35.67, 10.10, now(), false, 'Test', 'G', 'Blanc', '333 TU 3333') returning id into d_d;
  insert into public.wallets (user_id, balance, status, blocked_reason)
  values (u_d, 50, 'active', null), (u_p, 50, 'active', null)
  on conflict (user_id) do update set balance = excluded.balance, status = 'active', blocked_reason = null;

  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, d_d, 'ready', 'food', 30, 4.5, 34.5, 'cash', false) returning id into o1;
  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, 'pending', 'food', 20, 3.5, 23.5, 'cash', false) returning id into o2;
  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, v_v, 'pending', 'food', 20, 3.5, 23.5, 'cash', false) returning id into o3;

  -- ── G1 le livreur livre ──────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.orders set status = 'pickedUp' where id = o1;
  update public.orders set status = 'onTheWay' where id = o1;
  update public.orders set status = 'delivered' where id = o1;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 or (select status from public.orders where id = o1) <> 'delivered' then
    raise exception 'FAIL G1 : le livreur ne livre plus';
  end if;
  select count(*) into n from public.settlements where related_order_id = o1;
  if n <> 2 then raise exception 'FAIL G1 : % règlements (attendu 2)', n; end if;
  res := res || 'G1 ok; ';

  -- ── G2 écran pas à jour ──────────────────────────────────────────────────
  foreach st in array array['onTheWay', 'pickedUp', 'ready'] loop
    begin
      set local role authenticated;
      update public.orders set status = st where id = o1;
      raise exception 'FAIL G2 : le livreur fait sortir une commande livrée vers %', st;
    exception when raise_exception then
      get stacked diagnostics msg = message_text;
      if msg not like 'Delivered orders cannot change status%' then raise; end if;
    end;
    reset role;
  end loop;
  set local role authenticated;
  update public.orders set status = 'delivered' where id = o1;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL G2 : réenregistrer delivered est refusé'; end if;
  select count(*) into n from public.settlements where related_order_id = o1;
  if n <> 2 then raise exception 'FAIL G2 : % règlements après réenregistrement', n; end if;
  res := res || 'G2 ok; ';

  -- ── G3 client ────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    update public.orders set status = 'cancelled', cancellation_reason = 'test', cancelled_by = 'customer',
                             cancelled_at = now()
     where id = o1;
    raise exception 'FAIL G3 : le client annule une commande livrée';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'Delivered orders cannot change status%' then raise; end if;
  end;
  reset role;
  set local role authenticated;
  st := public.confirm_order_receipt(o1, true);
  reset role;
  if st is distinct from 'confirmed' then raise exception 'FAIL G3 : confirmation de réception (%)', st; end if;
  set local role authenticated;
  update public.orders set status = 'cancelled', cancellation_reason = 'test garde', cancelled_by = 'customer',
                           cancelled_at = now()
   where id = o2 and status in ('pending', 'confirmed', 'preparing', 'ready');
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL G3 : le client n''annule plus une commande en attente'; end if;
  res := res || 'G3 ok; ';

  -- ── G4 partenaire ────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_p, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.orders set status = 'confirmed' where id = o3;
  update public.orders set status = 'preparing' where id = o3;
  update public.orders set status = 'ready' where id = o3;
  update public.orders set self_delivery = true, status = 'onTheWay' where id = o3;
  update public.orders set status = 'delivered' where id = o3;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 or (select status from public.orders where id = o3) <> 'delivered' then
    raise exception 'FAIL G4 : le partenaire ne livre plus lui-même';
  end if;
  select count(*) into n3 from public.settlements where related_order_id = o3;
  begin
    set local role authenticated;
    update public.orders set status = 'ready' where id = o3;
    raise exception 'FAIL G4 : le partenaire fait sortir une commande livrée';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'Delivered orders cannot change status%' then raise; end if;
  end;
  reset role;
  if (select count(*) from public.settlements where related_order_id = o3) <> n3 then
    raise exception 'FAIL G4 : règlements modifiés';
  end if;
  res := res || 'G4 ok; ';

  -- ── G5 correction à la main (SQL Editor, postgres) ───────────────────────
  perform set_config('request.jwt.claims', '', true);
  select balance into bal_p from public.wallets where user_id = u_p;
  select balance into bal_d from public.wallets where user_id = u_d;
  update public.orders set status = 'onTheWay' where id = o1;
  update public.orders set status = 'delivered' where id = o1;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL G5 : une correction à la main est bloquée'; end if;
  select count(*) into n from public.settlements where related_order_id = o1;
  if n <> 2 or (select balance from public.wallets where user_id = u_p) <> bal_p
     or (select balance from public.wallets where user_id = u_d) <> bal_d then
    raise exception 'FAIL G5 : re-livraison à la main : % règlements, soldes % / %', n,
      (select balance from public.wallets where user_id = u_p), (select balance from public.wallets where user_id = u_d);
  end if;
  res := res || 'G5 ok; ';

  -- ── G6 service_role ──────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  set local role service_role;
  update public.orders set status = 'onTheWay' where id = o1;
  update public.orders set status = 'delivered' where id = o1;
  get diagnostics n = row_count;
  reset role;
  if n <> 1 then raise exception 'FAIL G6 : service_role bloqué'; end if;
  select count(*) into n from public.settlements where related_order_id = o1;
  if n <> 2 or (select balance from public.wallets where user_id = u_p) <> bal_p
     or (select balance from public.wallets where user_id = u_d) <> bal_d then
    raise exception 'FAIL G6 : re-livraison serveur : % règlements', n;
  end if;
  res := res || 'G6 ok; ';

  -- ── G7 la garde 'cancelled' tient toujours ──────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  begin
    set local role authenticated;
    update public.orders set status = 'pending' where id = o2;
    raise exception 'FAIL G7 : une commande annulée repart';
  exception when raise_exception then
    get stacked diagnostics msg = message_text;
    if msg not like 'Cancelled orders cannot change status%' then raise; end if;
  end;
  reset role;
  res := res || 'G7 ok';

  perform set_config('guard.results', res, true);
end
$test$;

select current_setting('guard.results', true) as resultats;

rollback;
