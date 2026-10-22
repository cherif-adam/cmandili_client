-- ============================================================================
-- CMANDILI / Amana — Harnais : suppression de compte
--
-- SÛR À LANCER EN PRODUCTION, par construction :
--   • une seule transaction, terminée par ROLLBACK ;
--   • les triggers UTILISATEUR de orders, settlements et wallets sont
--     coupés (ALTER TABLE ... DISABLE TRIGGER USER, annulé au ROLLBACK) :
--     aucune commande insérée ou modifiée ne réveille les push, aucun
--     règlement, aucun mouvement de solde. Les clés étrangères, triggers
--     système, restent actives : le test T8 en dépend. Le trigger
--     d'immuabilité des bons colis reste actif : T5, T12 et T13 en dépendent ;
--   • aucune écriture dans le Stockage (non transactionnel), et l'API GoTrue
--     n'est pas appelée : le harnais vérifie le bannissement posé en base et
--     la LISTE des fichiers que les Edge Functions retireraient.
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
--       portefeuille gardés, connexion bannie, sessions supprimées, relevé
--       sans téléphone, journal
--   T10 boutique supprimée : invisible pour un autre client, un visiteur et
--       les vues ; toujours visible dans l'historique de son client ;
--       commande refusée (VENUE_CLOSED)
--   T4  appel rejoué : already_deleted, rien ne bouge
--   T5  client colis : bloqué par la commande en cours, puis par le litige
--       ouvert ; une fois le litige clos, supprimé
--   T11 commandes terminées de ce client : comptabilité identique (montants,
--       statut, dates, articles, paiements) ; adresses, GPS, téléphones,
--       noms, notes, consignes, voix, photo de facture effacés ; nom du
--       destinataire effacé ; preuve de remise colis encore là ; fichiers à
--       retirer listés ; purge datée à dernière commande + 30 jours
--   T6  livreur : bloqué par la livraison, le litige et le solde ; en règle,
--       hors ligne, écarté, véhicule et positions effacés, relevé anonymisé ;
--       dossier d'identité et copie du bon gardés
--   T7  compte admin : refusé
--   T12 purge des preuves colis : rien avant l'échéance ; à l'échéance,
--       fichiers listés puis colonnes effacées (toute la preuve pour le
--       client, nom / plaque / CIN pour le livreur), bon gardé ; idempotente
--   T13 immuabilité du bon : hors effacement, rien ne se vide ; en
--       effacement, rien ne se réécrit ; jamais de suppression
--   T8  DELETE direct sur auth.users / drivers : refusé par les FK
--   T9  droits : anon n'exécute rien, authenticated seulement la
--       vérification, le journal est fermé aux deux
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
  o_p  uuid;   -- livrée, boutique P, client C
  o_b  uuid;   -- en préparation, boutique B, client C
  o_k  uuid;   -- colis de K, porté par D
  o_k2 uuid;   -- colis de C (toujours inscrit), porté par D
  o_f  uuid;   -- repas de K, livré
  o_bill uuid; -- facture de K, payée
  k_log uuid;
  d_log uuid;
  addr jsonb := jsonb_build_object(
    'id', 'a1', 'label', 'Maison', 'fullAddress', '12 rue du Test, Tunis',
    'latitude', 36.81, 'longitude', 10.17, 'apartmentNumber', '3', 'floor', '2',
    'instructions', 'Sonner deux fois', 'isDefault', true,
    'recipientName', 'Test K', 'phone', '+21600000000');
  url  text := 'https://example.invalid/storage/v1/object/public/';
  r    jsonb;
  codes text[];
  n    integer;
  ok   boolean;
  h_before text;
  h_after  text;
  acct_before  text;
  items_before text;
  pay_before   text;
  shop_before  text;
  res  text := '';
begin
  -- ── Préconditions ────────────────────────────────────────────────────────
  if to_regprocedure('public.account_deletion_purge_proofs(uuid[])') is null then
    raise exception 'PRECONDITION : account_deletion_purge_proofs absente. Lancez 20261017090000_account_deletion.sql.';
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
         avatar_url = url || 'profiles/' || id::text || '.jpg',
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

  insert into public.drivers (user_id, is_online, current_lat, current_lng, last_location_update, is_blocked,
                              vehicle_make, vehicle_model, vehicle_color, vehicle_plate)
  values (u_d, true, 36.8, 10.18, now(), false, 'Peugeot', 'Partner', 'Blanc', '123 TU 4567')
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

  -- Colis de K, en route avec D.
  insert into public.orders (user_id, driver_id, status, order_type, subtotal, delivery_fee, total,
                             recipient_name, recipient_phone, sender_phone, notes,
                             delivery_address, pickup_address, package_photo_url)
  values (u_k, d_d, 'onTheWay', 'courier', 0, 7, 7,
          'Destinataire', '+21633333333', '+21600000000', 'Fragile, appelez-moi',
          addr, addr, url || 'package-photos/colis-k.jpg')
  returning id into o_k;
  insert into public.colis_receipts (order_id, sender_name, sender_phone, driver_id, driver_name, driver_plate,
                                     description, declared_value, delivery_mode, receiver_label,
                                     pickup_at, pickup_photo_path, pickup_lat, pickup_lng,
                                     delivery_at, delivery_photo_path, delivery_lat, delivery_lng,
                                     proof_status)
  values (o_k, 'Test K', '+21600000000', d_d, 'Livreur Test', '123 TU 4567',
          'Colis test', 50, 'no_code', 'Concierge Ali',
          now() - interval '20 minutes', 'k/pickup.jpg', 36.80, 10.18,
          now() - interval '5 minutes', 'k/delivery.jpg', 36.81, 10.17,
          'complete');
  insert into public.colis_receipt_identity (order_id, driver_cin) values (o_k, 'CIN-D');

  -- Colis de C (client toujours inscrit), livré par D il y a 2 jours.
  insert into public.orders (user_id, driver_id, status, order_type, subtotal, delivery_fee, total, delivered_at)
  values (u_c, d_d, 'delivered', 'courier', 0, 7, 7, now() - interval '2 days')
  returning id into o_k2;
  insert into public.colis_receipts (order_id, sender_name, driver_id, driver_name, driver_plate,
                                     declared_value, delivery_mode,
                                     pickup_at, pickup_photo_path, pickup_lat, pickup_lng,
                                     delivery_at, delivery_photo_path, delivery_lat, delivery_lng,
                                     proof_status)
  values (o_k2, 'Client C', d_d, 'Livreur Test', '123 TU 4567',
          30, 'code',
          now() - interval '2 days 1 hour', 'k2/pickup.jpg', 36.70, 10.10,
          now() - interval '2 days', 'k2/delivery.jpg', 36.71, 10.11,
          'complete');
  insert into public.colis_receipt_identity (order_id, driver_cin) values (o_k2, 'CIN-D');
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng)
  values (o_k2, d_d, 'delivered', 36.71, 10.11);

  -- Repas de K, livré il y a 10 jours : article avec consigne et message vocal,
  -- paiement, position de livraison.
  insert into public.orders (user_id, restaurant_id, driver_id, status, order_type, subtotal, delivery_fee, total,
                             platform_fee, delivered_at, delivery_address, notes, payment_method)
  values (u_k, v_b, d_d, 'delivered', 'food', 20, 3, 23, 1, now() - interval '10 days', addr,
          'Appelez le 22 222 222', 'cash')
  returning id into o_f;
  insert into public.order_items (order_id, price, quantity, special_instructions, voice_note_url)
  values (o_f, 10, 2, 'Sans oignons, je suis au 2e', url || 'voice-messages/k-voice.m4a');
  insert into public.payments (order_id, user_id, amount, method, status)
  values (o_f, u_k, 23, 'cash', 'paid');
  insert into public.deliveries (order_id, driver_id, status, current_lat, current_lng)
  values (o_f, d_d, 'delivered', 36.81, 10.17);

  -- Facture de K, payée par Amana il y a 5 jours.
  insert into public.orders (user_id, status, order_type, subtotal, delivery_fee, total, delivered_at,
                             pickup_address, bill_reference, bill_amount, bill_photo_url, bill_receipt_url)
  values (u_k, 'delivered', 'facture', 80, 5, 85, now() - interval '5 days',
          addr, 'REF-123', 80, url || 'package-photos/facture-k.jpg', url || 'receipts/recu-k.jpg')
  returning id into o_bill;

  -- Relevés générés pour D et pour la boutique P.
  insert into public.generated_statements (reference_code, entity_type, entity_id, entity_name, entity_phone,
                                           date_from, date_to, generated_at, order_count, total_amount,
                                           total_commission, orders_snapshot)
  values ('TEST-D-' || d_d::text, 'driver', d_d::text, 'Livreur Test', '+21644444444',
          current_date - 30, current_date, now(), 1, 7, 1.6, '[]'::jsonb),
         ('TEST-P-' || v_p::text, 'restaurant', v_p::text, 'Boutique Test P', '+21611111111',
          current_date - 30, current_date, now(), 1, 12, 1.2, '[]'::jsonb);

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
  -- La photo de profil n'est pas le logo : elle est à retirer du Stockage.
  if r->'files' <> jsonb_build_array(jsonb_build_object('kind', 'avatar', 'ref', url || 'profiles/' || u_p::text || '.jpg')) then
    raise exception 'FAIL T3 fichiers : %', r;
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
  -- Relevé de la boutique : gardé avec son nom commercial, sans téléphone.
  if not exists (select 1 from public.generated_statements
                  where entity_id = v_p::text and entity_name = 'Boutique Test P' and entity_phone is null) then
    raise exception 'FAIL T3 : relevé boutique';
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
  -- Règle 1 : une commande pas terminée bloque.
  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"active_orders","count":1}]'::jsonb then
    raise exception 'FAIL T5a : %', r;
  end if;

  -- Livré, puis litige ouvert.
  update public.orders set status = 'delivered', delivered_at = now() where id = o_k;
  insert into public.colis_disputes (order_id, user_id, driver_id, kind, message)
  values (o_k, u_k, d_d, 'parcel_problem', 'Colis abîmé, appelez-moi au 22 333 444');

  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"open_disputes","count":1}]'::jsonb then
    raise exception 'FAIL T5b : %', r;
  end if;

  update public.colis_disputes set resolved_at = now(), resolution = 'test' where order_id = o_k;

  -- Ce que la comptabilité garde, et la preuve de remise, relevés avant.
  select md5(string_agg(concat_ws('|', id, status, order_type, subtotal, delivery_fee, total, platform_fee,
                                   driver_fee_cut, payment_method, created_at, delivered_at, cancelled_at,
                                   restaurant_id, supermarket_id, driver_id, bill_type, bill_reference,
                                   bill_amount, bill_receipt_url, package_photo_url), ';' order by id))
    into acct_before from public.orders where user_id = u_k;
  select md5(string_agg(concat_ws('|', id, order_id, vendor_item_id, food_item_id, price, quantity, options), ';' order by id))
    into items_before from public.order_items where order_id in (select id from public.orders where user_id = u_k);
  select md5(string_agg(row_to_json(p)::text, ';' order by p.id))
    into pay_before from public.payments p where p.order_id in (select id from public.orders where user_id = u_k);
  select md5(concat_ws('|', cr.pickup_photo_path, cr.delivery_photo_path, cr.pickup_lat, cr.pickup_lng,
                       cr.delivery_lat, cr.delivery_lng, cr.driver_id, cr.driver_name, cr.driver_plate,
                       cr.declared_value, cr.delivery_mode, cr.description, cr.pickup_at, cr.delivery_at,
                       cr.proof_status, cr.created_at, ci.driver_cin))
    into h_before
    from public.colis_receipts cr join public.colis_receipt_identity ci using (order_id)
   where cr.order_id = o_k;

  r := public.account_deletion_execute(u_k, 'client');
  if r->>'status' <> 'ok' or r->'roles' <> '["client"]'::jsonb then
    raise exception 'FAIL T5c : %', r;
  end if;
  k_log := (r->>'log_id')::uuid;
  res := res || 'T5 ok; ';

  -- ── T11 anonymisation des commandes terminées ────────────────────────────
  -- Fichiers à retirer tout de suite : photo de profil, photo de facture, voix.
  if not (r->'files' @> jsonb_build_array(
            jsonb_build_object('kind', 'avatar',     'ref', url || 'profiles/' || u_k::text || '.jpg'),
            jsonb_build_object('kind', 'bill_photo', 'ref', url || 'package-photos/facture-k.jpg'),
            jsonb_build_object('kind', 'voice_note', 'ref', url || 'voice-messages/k-voice.m4a')))
     or jsonb_array_length(r->'files') <> 3 then
    raise exception 'FAIL T11 fichiers : %', r->'files';
  end if;

  -- Comptabilité : identique, colonne par colonne.
  select md5(string_agg(concat_ws('|', id, status, order_type, subtotal, delivery_fee, total, platform_fee,
                                   driver_fee_cut, payment_method, created_at, delivered_at, cancelled_at,
                                   restaurant_id, supermarket_id, driver_id, bill_type, bill_reference,
                                   bill_amount, bill_receipt_url, package_photo_url), ';' order by id))
    into h_after from public.orders where user_id = u_k;
  if h_after is distinct from acct_before or (select count(*) from public.orders where user_id = u_k) <> 3 then
    raise exception 'FAIL T11 : montants, statut, dates ou facture modifiés';
  end if;
  select md5(string_agg(concat_ws('|', id, order_id, vendor_item_id, food_item_id, price, quantity, options), ';' order by id))
    into h_after from public.order_items where order_id in (select id from public.orders where user_id = u_k);
  if h_after is distinct from items_before then
    raise exception 'FAIL T11 : articles modifiés';
  end if;
  select md5(string_agg(row_to_json(p)::text, ';' order by p.id))
    into h_after from public.payments p where p.order_id in (select id from public.orders where user_id = u_k);
  if h_after is distinct from pay_before then
    raise exception 'FAIL T11 : paiements modifiés';
  end if;

  -- Ce qui la désignait ou la localisait : effacé.
  if exists (select 1 from public.orders
              where user_id = u_k
                and (   (delivery_address is not null and delivery_address <> '{"fullAddress": "Adresse supprimée"}'::jsonb)
                     or (pickup_address   is not null and pickup_address   <> '{"fullAddress": "Adresse supprimée"}'::jsonb)
                     or recipient_name  is not null
                     or recipient_phone is not null
                     or sender_phone    is not null
                     or notes           is not null
                     or bill_photo_url  is not null)) then
    raise exception 'FAIL T11 : adresse, téléphone, nom ou note encore présents';
  end if;
  if exists (select 1 from public.order_items
              where order_id = o_f and (special_instructions is not null or voice_note_url is not null))
     or exists (select 1 from public.deliveries
                 where order_id = o_f and (current_lat is not null or current_lng is not null)) then
    raise exception 'FAIL T11 : consigne, voix ou GPS de livraison encore présents';
  end if;
  -- Bon colis : expéditeur et destinataire effacés, preuve de remise intacte.
  if exists (select 1 from public.colis_receipts
              where order_id = o_k
                and (sender_name is not null or sender_phone is not null or receiver_label is not null)) then
    raise exception 'FAIL T11 : nom ou téléphone sur le bon colis';
  end if;
  select md5(concat_ws('|', cr.pickup_photo_path, cr.delivery_photo_path, cr.pickup_lat, cr.pickup_lng,
                       cr.delivery_lat, cr.delivery_lng, cr.driver_id, cr.driver_name, cr.driver_plate,
                       cr.declared_value, cr.delivery_mode, cr.description, cr.pickup_at, cr.delivery_at,
                       cr.proof_status, cr.created_at, ci.driver_cin))
    into h_after
    from public.colis_receipts cr join public.colis_receipt_identity ci using (order_id)
   where cr.order_id = o_k;
  if h_after is distinct from h_before then
    raise exception 'FAIL T11 : preuve de remise touchée avant les 30 jours';
  end if;
  if not exists (select 1 from public.colis_disputes
                  where order_id = o_k and message is null and kind = 'parcel_problem' and resolved_at is not null) then
    raise exception 'FAIL T11 : litige';
  end if;
  -- Purge due 30 jours après la dernière commande terminée (o_k, livrée maintenant).
  if not exists (select 1 from public.account_deletions
                  where id = k_log
                    and proof_purge_after between now() + interval '29 days' and now() + interval '31 days') then
    raise exception 'FAIL T11 : échéance de purge';
  end if;
  res := res || 'T11 ok; ';

  -- ── T6 livreur ───────────────────────────────────────────────────────────
  -- Le litige contre lui est rouvert, et la course remise en route, pour ce test.
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
  d_log := (r->>'log_id')::uuid;
  if not exists (select 1 from public.drivers
                  where id = d_d and user_id = u_d and is_online = false and is_blocked
                    and current_lat is null and current_lng is null
                    and vehicle_plate is null and vehicle_make is null
                    and vehicle_model is null and vehicle_color is null) then
    raise exception 'FAIL T6 : fiche livreur';
  end if;
  if exists (select 1 from public.deliveries
              where driver_id = d_d and (current_lat is not null or current_lng is not null)) then
    raise exception 'FAIL T6 : positions de livraison encore présentes';
  end if;
  if not exists (select 1 from public.generated_statements
                  where entity_id = d_d::text and entity_name = 'Compte supprimé' and entity_phone is null) then
    raise exception 'FAIL T6 : relevé livreur';
  end if;
  -- Gardés : dossier d'identité (admin), et la copie du bon jusqu'à la purge.
  if not exists (select 1 from public.driver_identity where driver_id = d_d and cin = '00000000')
     or not exists (select 1 from public.colis_receipts
                     where order_id = o_k2 and driver_id = d_d and driver_plate = '123 TU 4567') then
    raise exception 'FAIL T6 : dossier ou bon perdu';
  end if;
  res := res || 'T6 ok; ';

  -- ── T7 admin ─────────────────────────────────────────────────────────────
  r := public.account_deletion_execute(u_a, 'client');
  if r->>'status' <> 'blocked' or r->'blockers' <> '[{"code":"admin_account"}]'::jsonb then
    raise exception 'FAIL T7 : %', r;
  end if;
  res := res || 'T7 ok; ';

  -- ── T12 purge des preuves colis ──────────────────────────────────────────
  -- Avant l'échéance : rien n'est dû.
  if exists (select 1 from jsonb_array_elements(public.account_deletion_due_proofs()) e
              where (e->>'deletion_id')::uuid in (k_log, d_log)) then
    raise exception 'FAIL T12 : purge due avant 30 jours';
  end if;
  if public.account_deletion_purge_proofs(array[k_log, d_log]) <> 0 then
    raise exception 'FAIL T12 : purge faite avant 30 jours';
  end if;

  -- Échéance passée (on avance la date au lieu d'attendre 30 jours).
  update public.account_deletions set proof_purge_after = now() - interval '1 second' where id in (k_log, d_log);

  r := public.account_deletion_due_proofs();
  select e->'files' into r from jsonb_array_elements(public.account_deletion_due_proofs()) e
   where (e->>'deletion_id')::uuid = k_log;
  if r is null
     or not (r @> jsonb_build_array(
               jsonb_build_object('kind', 'colis_proof',   'ref', 'k/pickup.jpg'),
               jsonb_build_object('kind', 'colis_proof',   'ref', 'k/delivery.jpg'),
               jsonb_build_object('kind', 'package_photo', 'ref', url || 'package-photos/colis-k.jpg')))
     or jsonb_array_length(r) <> 3 then
    raise exception 'FAIL T12 fichiers client : %', r;
  end if;
  -- Livreur : les photos des colis qu'il a portés appartiennent aux clients.
  select e->'files' into r from jsonb_array_elements(public.account_deletion_due_proofs()) e
   where (e->>'deletion_id')::uuid = d_log;
  if r is distinct from '[]'::jsonb then
    raise exception 'FAIL T12 fichiers livreur : %', r;
  end if;

  select md5(concat_ws('|', declared_value, delivery_mode, description, pickup_at, delivery_at,
                       proof_status, created_at, driver_id, code_verified))
    into h_before from public.colis_receipts where order_id = o_k;

  if public.account_deletion_purge_proofs(array[k_log, d_log]) <> 2 then
    raise exception 'FAIL T12 : purge non faite';
  end if;

  -- Envoi du client : toute la preuve effacée, le bon gardé.
  if not exists (select 1 from public.colis_receipts
                  where order_id = o_k and proof_erased_at is not null
                    and pickup_photo_path is null and delivery_photo_path is null
                    and pickup_lat is null and pickup_lng is null
                    and delivery_lat is null and delivery_lng is null
                    and driver_name is null and driver_plate is null)
     or exists (select 1 from public.colis_receipt_identity where order_id = o_k and driver_cin is not null)
     or exists (select 1 from public.orders where id = o_k and package_photo_url is not null) then
    raise exception 'FAIL T12 : preuve du client encore présente';
  end if;
  select md5(concat_ws('|', declared_value, delivery_mode, description, pickup_at, delivery_at,
                       proof_status, created_at, driver_id, code_verified))
    into h_after from public.colis_receipts where order_id = o_k;
  if h_after is distinct from h_before then
    raise exception 'FAIL T12 : le bon lui-même a changé';
  end if;

  -- Colis d'un client toujours inscrit, porté par le livreur supprimé : ce
  -- qui désigne le livreur part, la preuve du client reste.
  if not exists (select 1 from public.colis_receipts
                  where order_id = o_k2 and driver_name is null and driver_plate is null
                    and pickup_photo_path = 'k2/pickup.jpg' and delivery_photo_path = 'k2/delivery.jpg'
                    and pickup_lat = 36.70 and delivery_lat = 36.71
                    and sender_name = 'Client C' and proof_erased_at is null)
     or exists (select 1 from public.colis_receipt_identity where order_id = o_k2 and driver_cin is not null) then
    raise exception 'FAIL T12 : bon du colis porté par le livreur';
  end if;

  if (select count(*) from public.account_deletions where id in (k_log, d_log) and proof_purged_at is not null) <> 2
     or public.account_deletion_purge_proofs(array[k_log, d_log]) <> 0
     or exists (select 1 from jsonb_array_elements(public.account_deletion_due_proofs()) e
                 where (e->>'deletion_id')::uuid in (k_log, d_log)) then
    raise exception 'FAIL T12 : purge non idempotente';
  end if;
  res := res || 'T12 ok; ';

  -- ── T13 immuabilité du bon colis ─────────────────────────────────────────
  -- Hors effacement : une preuve enregistrée ne se vide pas.
  ok := false;
  begin
    update public.colis_receipts set pickup_photo_path = null where order_id = o_k2;
  exception when raise_exception then ok := true;
  end;
  if not ok then raise exception 'FAIL T13 : preuve vidée hors effacement'; end if;

  ok := false;
  begin
    update public.colis_receipts set proof_erased_at = now() where order_id = o_k2;
  exception when raise_exception then ok := true;
  end;
  if not ok then raise exception 'FAIL T13 : proof_erased_at posé hors effacement'; end if;

  -- En effacement : on vide, on ne réécrit pas, et le reste ne bouge pas.
  perform set_config('amana.erasing_personal_data', 'on', true);
  ok := false;
  begin
    update public.colis_receipts set pickup_photo_path = 'autre.jpg' where order_id = o_k2;
  exception when raise_exception then ok := true;
  end;
  if not ok then raise exception 'FAIL T13 : preuve réécrite en effacement'; end if;

  ok := false;
  begin
    update public.colis_receipts set declared_value = 1 where order_id = o_k2;
  exception when raise_exception then ok := true;
  end;
  if not ok then raise exception 'FAIL T13 : valeur déclarée modifiée en effacement'; end if;

  ok := false;
  begin
    delete from public.colis_receipts where order_id = o_k2;
  exception when raise_exception then ok := true;
  end;
  if not ok then raise exception 'FAIL T13 : bon supprimé en effacement'; end if;
  perform set_config('amana.erasing_personal_data', 'off', true);

  if (select pickup_photo_path from public.colis_receipts where order_id = o_k2) is distinct from 'k2/pickup.jpg' then
    raise exception 'FAIL T13 : le bon a changé';
  end if;
  res := res || 'T13 ok; ';

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
     or has_function_privilege('anon', 'public.account_deletion_due_proofs()', 'execute')
     or has_function_privilege('anon', 'public.account_deletion_purge_proofs(uuid[])', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_execute(uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_blockers(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_due_proofs()', 'execute')
     or has_function_privilege('authenticated', 'public.account_deletion_purge_proofs(uuid[])', 'execute')
     or not has_function_privilege('authenticated', 'public.account_deletion_check()', 'execute')
     or not has_function_privilege('service_role', 'public.account_deletion_execute(uuid,text)', 'execute')
     or not has_function_privilege('service_role', 'public.account_deletion_purge_proofs(uuid[])', 'execute')
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
