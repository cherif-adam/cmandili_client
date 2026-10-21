-- ============================================================================
-- CMANDILI / Amana — Harnais : suppression de compte
--
-- SÛR À LANCER EN PRODUCTION, par construction :
--   • une seule transaction, terminée par ROLLBACK ;
--   • les triggers UTILISATEUR de orders, settlements et wallets sont
--     coupés (ALTER TABLE ... DISABLE TRIGGER USER, annulé au ROLLBACK) :
--     aucune commande insérée ou modifiée ne réveille les push, aucun
--     règlement, aucun mouvement de solde. Les clés étrangères, triggers
--     système, restent actives : le test T8 en dépend ;
--   • aucune écriture dans le Stockage (non transactionnel), et l'API GoTrue
--     n'est pas appelée : le harnais vérifie le bannissement posé en base.
--
-- À lancer d'un bloc dans le SQL Editor, APRÈS
-- 20261017090000_account_deletion.sql. Le résultat est la dernière ligne.
--
-- Ce qui est vérifié :
--   T1  partenaire bloqué (commande en cours + solde) : rien ne change, refus
--       journalisé
--   T2  account_deletion_check() vu par ce partenaire : mêmes blocages
--   T3  partenaire en règle : données perso supprimées, profil anonymisé,
--       boutique fermée et marquée, produits, commandes, règlements et
--       portefeuille gardés, connexion bannie, sessions supprimées, journal
--   T4  appel rejoué : already_deleted, rien ne bouge
--   T5  client colis : bloqué par la commande en cours, puis par le litige
--       ouvert ; une fois le litige clos, supprimé ; bon colis intact
--   T6  livreur : bloqué par la livraison, le litige et le solde ; en règle,
--       mis hors ligne et écarté ; dossier d'identité gardé
--   T7  compte admin : refusé
--   T8  DELETE direct sur auth.users : refusé par les clés étrangères
--   T9  droits : anon n'exécute rien, authenticated seulement la
--       vérification, le journal est fermé aux deux
--   T10 boutique supprimée : invisible pour un autre client, un visiteur et
--       les vues ; toujours visible dans l'historique de son client ;
--       commande refusée (VENUE_CLOSED)
-- ============================================================================

begin;

do $test$
declare
  u_p  uuid := gen_random_uuid();  -- partenaire en règle
  u_b  uuid := gen_random_uuid();  -- partenaire bloqué
  u_c  uuid := gen_random_uuid();  -- client des boutiques (jamais supprimé)
  u_k  uuid := gen_random_uuid();  -- client colis
  u_d  uuid := gen_random_uuid();  -- livreur
  u_a  uuid := gen_random_uuid();  -- admin
  v_p  uuid;
  v_b  uuid;
  d_d  uuid;
  o_p  uuid;
  o_b  uuid;
  o_k  uuid;
  r    jsonb;
  codes text[];
  n    integer;
  h_before text;
  h_after  text;
  shop_before text;
  res  text := '';
begin
  -- ── Préconditions ────────────────────────────────────────────────────────
  if to_regprocedure('public.account_deletion_execute(uuid,text)') is null then
    raise exception 'PRECONDITION : account_deletion_execute absente. Lancez 20261017090000_account_deletion.sql.';
  end if;

  -- ── Jeu d'essai ──────────────────────────────────────────────────────────
  -- Triggers UTILISATEUR coupés sur les tables qui notifient ou déplacent de
  -- l'argent : push et notifications de commande, règlements, solde. Les
  -- clés étrangères (triggers système) restent actives. Le rôle de la CLI ne
  -- peut pas poser session_replication_role ; ALTER TABLE est annulé avec le
  -- reste au ROLLBACK.
  alter table public.orders      disable trigger user;
  alter table public.settlements disable trigger user;
  alter table public.wallets     disable trigger user;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'acctdel-' || u::text || '@test.invalid',
         jsonb_build_object('full_name', 'Test ' || u::text, 'phone', '+21600000000'),
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_p, u_b, u_c, u_k, u_d, u_a]) as u;

  -- Le profil est créé par on_auth_user_created (auth.users, non modifiable
  -- ici) ; on le complète.
  update public.profiles
     set full_name  = 'Test ' || id::text,
         phone      = '+21600000000',
         email      = 'acctdel-' || id::text || '@test.invalid',
         avatar_url = 'https://example.invalid/storage/v1/object/public/profiles/' || id::text || '.jpg',
         is_admin   = (id = u_a),
         is_blocked = false
   where id = any (array[u_p, u_b, u_c, u_k, u_d, u_a]);
  get diagnostics n = row_count;
  if n <> 6 then
    raise exception 'PRECONDITION : on_auth_user_created n a pas cree les 6 profils (%)', n;
  end if;

  insert into public.vendors (category, name, is_open, owner_id, image_url, description)
  values ('food', 'Boutique Test P', true, u_p, 'https://example.invalid/logo-p.jpg', 'desc P')
  returning id into v_p;
  insert into public.vendors (category, name, is_open, owner_id)
  values ('food', 'Boutique Test B', true, u_b)
  returning id into v_b;
  insert into public.vendor_items (vendor_id, name) values (v_p, 'Plat test P');

  insert into public.partners (user_id, partner_type, entity_id, business_name, phone, address, bio, avatar_url)
  values (u_p, 'restaurant', v_p, 'Boutique Test P', '+21611111111', 'Rue test', 'bio', 'https://example.invalid/logo-p.jpg'),
         (u_b, 'restaurant', v_b, 'Boutique Test B', '+21622222222', 'Rue B',   null,  null);

  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked, vehicle_plate)
  values (u_d, true, 36.8, 10.18, now(), false, '123 TU 4567')
  returning id into d_d;
  insert into public.driver_identity (driver_id, cin) values (d_d, '00000000');

  insert into public.wallets (user_id, balance, status, blocked_reason)
  values (u_p, 0,    'blocked', 'balance'),
         (u_b, 12.5, 'active',  null),
         (u_d, 5,    'active',  null);

  insert into public.settlements (user_id, entity_type, amount, type, status)
  values (u_p, 'restaurant', -1.5, 'commission_deduction', 'paid'),
         (u_p, 'restaurant',  1.5, 'manual_topup',         'paid');

  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total)
  values (u_c, v_p, 'delivered', 'food', 10, 2, 12) returning id into o_p;
  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total)
  values (u_c, v_b, 'preparing', 'food', 10, 2, 12) returning id into o_b;
  insert into public.orders (user_id, driver_id, status, order_type, subtotal, delivery_fee, total, recipient_name, recipient_phone)
  values (u_k, d_d, 'onTheWay', 'courier', 0, 7, 7, 'Destinataire', '+21633333333') returning id into o_k;

  insert into public.colis_receipts (order_id, sender_name, sender_phone, driver_id, driver_name, driver_plate,
                                     description, declared_value, delivery_mode, pickup_at, proof_status)
  values (o_k, 'Test K', '+21600000000', d_d, 'Livreur Test', '123 TU 4567',
          'Colis test', 50, 'code', now() - interval '20 minutes', 'pickup_only');

  insert into public.device_tokens (token, user_id, platform) values ('acctdel-tok-' || u_p::text, u_p, 'android');
  insert into public.chat_messages (user_id, text, is_user) values (u_p, 'bonjour', true);
  insert into public.notifications (user_id, title, body) values (u_p, 't', 'b');
  insert into public.partner_payout_info (user_id, account_holder, bank_name, iban) values (u_p, 'Test P', 'Banque', 'TN5900000000000000000000');
  insert into auth.sessions (id, user_id) values (gen_random_uuid(), u_p);

  -- ── T1 partenaire bloqué ─────────────────────────────────────────────────
  r := public.account_deletion_execute(u_b, 'partner');
  select array_agg(e->>'code' order by e->>'code') into codes from jsonb_array_elements(r->'blockers') e;
  if r->>'status' <> 'blocked' or codes <> array['shop_active_orders', 'wallet_balance'] then
    raise exception 'FAIL T1 : %', r;
  end if;
  if (select (e->>'amount')::numeric from jsonb_array_elements(r->'blockers') e where e->>'code' = 'wallet_balance') <> 12.5 then
    raise exception 'FAIL T1 montant : %', r;
  end if;
  if (select full_name from public.profiles where id = u_b) is distinct from 'Test ' || u_b::text
     or (select is_open from public.vendors where id = v_b) is not true
     or (select banned_until from auth.users where id = u_b) is not null then
    raise exception 'FAIL T1 : un compte bloqué a été modifié';
  end if;
  if not exists (select 1 from public.account_deletions
                  where user_id = u_b and app = 'partner' and status = 'blocked'
                    and roles = array['partner'] and blockers = r->'blockers') then
    raise exception 'FAIL T1 : refus non journalisé';
  end if;
  res := res || 'T1 ok; ';

  -- ── T2 vérification vue par l'app ────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.account_deletion_check();
  reset role;
  select array_agg(e->>'code' order by e->>'code') into codes from jsonb_array_elements(r->'blockers') e;
  if codes is distinct from array['shop_active_orders', 'wallet_balance'] then
    raise exception 'FAIL T2 : %', r;
  end if;
  res := res || 'T2 ok; ';

  -- ── T3 partenaire en règle ───────────────────────────────────────────────
  -- Nom, description et logo de la boutique, tels qu'avant (le trigger
  -- sync_partner_shop_fields a déjà recopié la bio à l'insertion).
  select md5(concat_ws('|', name, description, image_url)) into shop_before from public.vendors where id = v_p;
  r := public.account_deletion_execute(u_p, 'partner');
  if r->>'status' <> 'ok' then
    raise exception 'FAIL T3 statut : %', r;
  end if;
  -- La photo de profil n'est pas le logo : elle est renvoyée pour le Stockage.
  if r->>'avatar_url' is distinct from 'https://example.invalid/storage/v1/object/public/profiles/' || u_p::text || '.jpg' then
    raise exception 'FAIL T3 avatar_url : %', r;
  end if;
  if not exists (select 1 from public.profiles
                  where id = u_p and full_name = 'Compte supprimé' and phone is null and email is null
                    and avatar_url is null and is_blocked and deleted_at is not null) then
    raise exception 'FAIL T3 : profil non anonymisé';
  end if;
  select count(*) into n from (
    select 1 from public.device_tokens       where user_id = u_p union all
    select 1 from public.chat_messages       where user_id = u_p union all
    select 1 from public.notifications       where user_id = u_p union all
    select 1 from public.partner_payout_info where user_id = u_p) x;
  if n <> 0 then
    raise exception 'FAIL T3 : % ligne(s) personnelle(s) restante(s)', n;
  end if;
  if not exists (select 1 from public.partners
                  where user_id = u_p and phone is null and address is null and bio is null
                    and avatar_url is null and is_blocked and business_name = 'Boutique Test P') then
    raise exception 'FAIL T3 : fiche partenaire';
  end if;
  if not exists (select 1 from public.vendors
                  where id = v_p and is_open = false and deleted_at is not null
                    and md5(concat_ws('|', name, description, image_url)) = shop_before) then
    raise exception 'FAIL T3 : boutique';
  end if;
  if (select count(*) from public.vendor_items where vendor_id = v_p) <> 1
     or not exists (select 1 from public.orders where id = o_p and user_id = u_c and restaurant_id = v_p)
     or (select count(*) from public.settlements where user_id = u_p) <> 2
     or not exists (select 1 from public.wallets where user_id = u_p and status = 'blocked' and blocked_reason = 'manual') then
    raise exception 'FAIL T3 : historique perdu';
  end if;
  if not exists (select 1 from auth.users
                  where id = u_p and banned_until > now() + interval '99 years'
                    and raw_user_meta_data = '{}'::jsonb)
     or exists (select 1 from auth.sessions where user_id = u_p) then
    raise exception 'FAIL T3 : connexion encore possible';
  end if;
  if not exists (select 1 from public.account_deletions
                  where user_id = u_p and status = 'auth_pending' and app = 'partner'
                    and blockers = '[]'::jsonb and id = (r->>'log_id')::uuid) then
    raise exception 'FAIL T3 : journal';
  end if;
  -- Les autres comptes n'ont pas bougé.
  if (select full_name from public.profiles where id = u_c) is distinct from 'Test ' || u_c::text then
    raise exception 'FAIL T3 : un autre profil a été touché';
  end if;
  res := res || 'T3 ok; ';

  -- ── T10 boutique supprimée invisible, sauf dans l'historique ─────────────
  -- Le client qui y a commandé la voit encore (son historique), un autre
  -- client et un visiteur non connecté ne la voient plus.
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.vendors where id = v_p;
  reset role;
  if n <> 1 then
    raise exception 'FAIL T10 : le client de la boutique ne la voit plus dans son historique';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', u_k, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.vendors where id = v_p;
  reset role;
  if n <> 0 then
    raise exception 'FAIL T10 : boutique supprimée visible par un autre client';
  end if;

  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
  select count(*) into n from public.vendors where id = v_p;
  reset role;
  if n <> 0 then
    raise exception 'FAIL T10 : boutique supprimée visible sans connexion';
  end if;
  -- Et sans connexion, les boutiques normales se lisent toujours (une
  -- première version de la policy cassait toute lecture anon de vendors).
  set local role anon;
  select count(*) into n from public.vendors where id = v_b;
  reset role;
  if n <> 1 then
    raise exception 'FAIL T10 : lecture anon des boutiques cassée';
  end if;

  -- La boutique B, non supprimée, reste visible de tous.
  perform set_config('request.jwt.claims', json_build_object('sub', u_k, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.vendors where id = v_b;
  reset role;
  if n <> 1 then
    raise exception 'FAIL T10 : une boutique normale a disparu';
  end if;

  if exists (select 1 from public.restaurants where id = v_p)
     or exists (select 1 from public.food_items where restaurant_id = v_p)
     or not exists (select 1 from public.restaurants where id = v_b) then
    raise exception 'FAIL T10 : vues restaurants / food_items';
  end if;

  -- Commander dans la boutique supprimée : refusé par enforce_venue_open,
  -- rallumé le temps de ce test (les autres triggers de orders restent coupés).
  alter table public.orders enable trigger enforce_venue_open;
  begin
    insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total)
    values (u_c, v_p, 'pending', 'food', 10, 2, 12);
    raise exception 'FAIL T10 : commande acceptée sur une boutique supprimée';
  exception when raise_exception then
    if sqlerrm <> 'VENUE_CLOSED' then
      raise;
    end if;
  end;
  alter table public.orders disable trigger enforce_venue_open;
  res := res || 'T10 ok; ';

  -- ── T4 appel rejoué ──────────────────────────────────────────────────────
  r := public.account_deletion_execute(u_p, 'partner');
  if r->>'status' <> 'already_deleted' then
    raise exception 'FAIL T4 : %', r;
  end if;
  if (select count(*) from public.account_deletions where user_id = u_p) <> 1 then
    raise exception 'FAIL T4 : journal en double';
  end if;
  res := res || 'T4 ok; ';

  -- ── T5 client colis ──────────────────────────────────────────────────────
  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"active_orders","count":1}]'::jsonb then
    raise exception 'FAIL T5a : %', r;
  end if;

  -- Livré, puis litige ouvert (triggers de orders coupés : ni push ni règlement).
  update public.orders set status = 'delivered', delivered_at = now() where id = o_k;
  insert into public.colis_disputes (order_id, user_id, driver_id, kind, message)
  values (o_k, u_k, d_d, 'parcel_problem', 'abîmé');

  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"open_disputes","count":1}]'::jsonb then
    raise exception 'FAIL T5b : %', r;
  end if;

  update public.colis_disputes set resolved_at = now(), resolution = 'test' where order_id = o_k;
  select md5(row_to_json(cr)::text) into h_before from public.colis_receipts cr where order_id = o_k;
  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'ok' or r->'roles' <> '["client"]'::jsonb then
    raise exception 'FAIL T5c : %', r;
  end if;
  select md5(row_to_json(cr)::text) into h_after from public.colis_receipts cr where order_id = o_k;
  if h_after is distinct from h_before then
    raise exception 'FAIL T5 : bon colis modifié';
  end if;
  if not exists (select 1 from public.orders
                  where id = o_k and user_id = u_k and recipient_phone = '+21633333333')
     or not exists (select 1 from public.colis_disputes where order_id = o_k and user_id = u_k) then
    raise exception 'FAIL T5 : commande ou litige perdu';
  end if;
  res := res || 'T5 ok; ';

  -- ── T6 livreur ───────────────────────────────────────────────────────────
  -- La livraison est terminée (T5), mais le litige contre lui était ouvert :
  -- on le rouvre pour ce test.
  update public.colis_disputes set resolved_at = null where order_id = o_k;
  update public.orders set status = 'onTheWay' where id = o_k;

  r := public.account_deletion_execute(u_d, 'driver');
  select array_agg(e->>'code' order by e->>'code') into codes from jsonb_array_elements(r->'blockers') e;
  if r->>'status' <> 'blocked' or codes <> array['driver_active_orders', 'driver_open_disputes', 'wallet_balance'] then
    raise exception 'FAIL T6a : %', r;
  end if;

  update public.orders set status = 'delivered' where id = o_k;
  update public.wallets set balance = 0 where user_id = u_d;
  update public.colis_disputes set resolved_at = now() where order_id = o_k;

  r := public.account_deletion_execute(u_d, 'driver');
  if r->>'status' <> 'ok' or r->'roles' <> '["driver"]'::jsonb then
    raise exception 'FAIL T6b : %', r;
  end if;
  if not exists (select 1 from public.drivers
                  where id = d_d and user_id = u_d and is_online = false and is_blocked
                    and current_lat is null and current_lng is null and vehicle_plate = '123 TU 4567')
     or not exists (select 1 from public.driver_identity where driver_id = d_d and cin = '00000000')
     or not exists (select 1 from public.colis_receipts where order_id = o_k and driver_id = d_d) then
    raise exception 'FAIL T6 : livreur';
  end if;
  res := res || 'T6 ok; ';

  -- ── T7 admin ─────────────────────────────────────────────────────────────
  r := public.account_deletion_execute(u_a, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"admin_account"}]'::jsonb then
    raise exception 'FAIL T7 : %', r;
  end if;
  res := res || 'T7 ok; ';

  -- ── T8 suppression directe refusée ───────────────────────────────────────
  begin
    delete from auth.users where id = u_p;
    raise exception 'FAIL T8 : DELETE auth.users accepté';
  exception when foreign_key_violation then
    null;
  end;
  begin
    delete from public.drivers where id = d_d;
    raise exception 'FAIL T8 : DELETE drivers accepté (dossier identité perdu)';
  exception when foreign_key_violation then
    null;
  end;
  if not exists (select 1 from public.orders where id = o_p)
     or (select count(*) from public.settlements where user_id = u_p) <> 2 then
    raise exception 'FAIL T8 : historique perdu';
  end if;
  res := res || 'T8 ok; ';

  -- ── T9 droits ────────────────────────────────────────────────────────────
  if has_function_privilege('anon', 'public.account_deletion_check()', 'execute')
     or has_function_privilege('anon', 'public.account_deletion_execute(uuid,text)', 'execute')
     or has_function_privilege('anon', 'public.account_deletion_blockers(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_execute(uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_blockers(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.account_deletion_check()', 'execute')
     or not has_function_privilege('service_role', 'public.account_deletion_execute(uuid,text)', 'execute')
     or has_table_privilege('anon', 'public.account_deletions', 'select')
     or has_table_privilege('authenticated', 'public.account_deletions', 'select')
     or has_table_privilege('authenticated', 'public.account_deletions', 'insert') then
    raise exception 'FAIL T9 : droits';
  end if;
  res := res || 'T9 ok';

  perform set_config('acct_del.results', res, true);
end
$test$;

select current_setting('acct_del.results', true) as resultats;

rollback;
