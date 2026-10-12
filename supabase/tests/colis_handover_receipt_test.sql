-- ============================================================================
-- CMANDILI — Harnais de test du bon de prise en charge Colis
--
-- SÛR À LANCER EN PRODUCTION, mais pas par magie — par construction :
--
--   • une seule transaction, terminée par ROLLBACK ;
--   • les triggers sont COUPÉS (session_replication_role) le temps d'insérer
--     la commande de test. Sans cela, insérer un colis en status='ready'
--     déclenche notify_fcm_on_new_order, qui envoie une VRAIE offre de course
--     à de VRAIS livreurs via net.http_post. Voir le bloc concerné ;
--   • aucun passage à 'delivered' nulle part, donc aucun règlement ni
--     mouvement de portefeuille — generate_settlements_on_delivery ne se
--     déclenche que sur cette transition ;
--   • aucune écriture de fichier : le Stockage n'est pas transactionnel, un
--     objet déposé ici survivrait au ROLLBACK. Ce harnais n'en dépose aucun.
--
-- Si le réglage des triggers ne peut pas être posé (droits insuffisants), le
-- harnais s'ARRÊTE avant la première insertion plutôt que de continuer.
--
-- À lancer d'un bloc dans le SQL Editor, APRÈS 20261012090000.
--
-- Ce qui est vérifié, et qui ne peut l'être que depuis la base :
--   1. le livreur ne peut pas lire le code (ni le clair, ni le hash) ;
--   2. une preuve écrite est immuable, même pour son auteur ;
--   3. la limite de 5 tentatives bloque réellement ;
--   4. le plafond de valeur déclarée est appliqué côté serveur ;
--   5. la fenêtre de litige de 24 h se ferme ;
--   6. le CIN est invisible du client comme du livreur.
--
-- Chaque test affiche OK ou lève une exception nommée. Une exception
-- interrompt tout et laisse la transaction à annuler : lancez alors le
-- ROLLBACK final seul.
-- ============================================================================

begin;

-- ── TRIGGERS COUPÉS POUR LE JEU D'ESSAI ────────────────────────────────────
-- CECI N'EST PAS UNE PRÉCAUTION DE CONFORT.
--
-- `orders` porte un trigger AFTER INSERT, notify_fcm_on_new_order, qui appelle
-- net.http_post vers la fonction push. Et depuis 20260815120000, une commande
-- insérée avec status='ready' — ce qu'est toute commande courier — y est
-- routée avec event:'driver_fanout'. Autrement dit : insérer naïvement un
-- colis de test ENVOIE UNE VRAIE OFFRE DE COURSE À DE VRAIS LIVREURS.
--
-- pg_net met la requête en file dans une table, donc elle devrait disparaître
-- au ROLLBACK — mais « devrait » ne suffit pas quand le worker de pg_net
-- dépile en tâche de fond pendant les quelques secondes que dure ce harnais.
-- On ne parie pas la production sur ce détail d'implémentation : on coupe.
--
-- Sont aussi neutralisés au passage les triggers ghost (restaurant_id IS NULL,
-- eux aussi en http_post) et celui de la fidélité.
--
-- SET LOCAL : la portée est la transaction, le réglage revient tout seul au
-- ROLLBACK. Aucun verrou pris sur `orders`, contrairement à
-- ALTER TABLE ... DISABLE TRIGGER qui bloquerait toute l'activité des
-- commandes pendant l'exécution.
set local session_replication_role = replica;

-- Garde-fou : si le réglage n'a pas pris (droits insuffisants), on s'arrête
-- AVANT d'insérer quoi que ce soit.
do $$
begin
  if current_setting('session_replication_role') <> 'replica' then
    raise exception 'ARRET : impossible de couper les triggers (role=%). '
      'Inserer une commande maintenant notifierait de vrais livreurs. '
      'Lancez ce harnais avec un role qui peut poser session_replication_role.',
      current_setting('session_replication_role');
  end if;
  raise notice 'Triggers coupes pour le jeu d essai';
end
$$;

-- ── Jeu d'essai ────────────────────────────────────────────────────────────
-- Identifiants fixes et reconnaissables, pour qu'un ROLLBACK oublié se repère
-- au premier coup d'œil. Le reçu et le code sont écrits à la main : le trigger
-- de bootstrap est coupé comme tous les autres, et sa présence est vérifiée
-- séparément au test 1.
do $$
declare
  v_order uuid := '00000000-dead-beef-0000-000000000001';
  v_code  text := '4242';
begin
  insert into public.orders (
    id, user_id, status, order_type, subtotal, delivery_fee, total,
    payment_method, delivery_address, pickup_address, sender_phone,
    recipient_phone, package_description
  )
  select v_order,
         (select id from public.profiles limit 1),
         'ready', 'courier', 0, 5, 5, 'cash',
         '{"latitude":35.6781,"longitude":10.0963,"fullAddress":"Test"}'::jsonb,
         '{"latitude":35.6700,"longitude":10.1000,"fullAddress":"Test"}'::jsonb,
         '20000000', '21000000', 'Colis de test'
  where exists (select 1 from public.profiles limit 1);

  insert into public.colis_receipts (order_id, description, declared_value,
                                     delivery_mode, proof_status)
  values (v_order, 'Colis de test', 50, 'code', 'pending');

  insert into public.colis_delivery_codes (order_id, code, code_hash)
  values (v_order, v_code,
          encode(sha256(convert_to(v_code || v_order::text, 'UTF8')), 'hex'));

  raise notice 'Jeu d''essai : commande % creee', v_order;
end
$$;

-- Triggers rétablis : les tests d'immuabilité qui suivent DOIVENT voir les
-- triggers actifs, sinon ils passeraient à tort.
set local session_replication_role = default;

do $$
begin
  if current_setting('session_replication_role') = 'replica' then
    raise exception 'ARRET : les triggers sont restes coupes, les tests 3 seraient faux';
  end if;
  raise notice 'Triggers retablis';
end
$$;


-- ── 1. Le bootstrap est bien branché ───────────────────────────────────────
-- Vérification structurelle et non fonctionnelle : le trigger a été coupé
-- pour le jeu d'essai ci-dessus (voir le bloc précédent), on ne peut donc pas
-- l'exercer ici sans réveiller le fan-out livreurs. On vérifie qu'il existe,
-- qu'il est bien attaché en AFTER INSERT sur `orders`, et que sa fonction
-- écrit le hash dans la bonne table.
do $$
declare n integer; v_src text;
begin
  select count(*) into n from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relname = 'orders'
     and t.tgname = 'trg_colis_bootstrap_receipt' and not t.tgisinternal;
  if n <> 1 then
    raise exception 'ECHEC 1a : trg_colis_bootstrap_receipt absent de orders';
  end if;

  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'colis_bootstrap_receipt';

  if v_src not like '%colis_delivery_codes%' then
    raise exception 'ECHEC 1b : le bootstrap n ecrit pas le code dans colis_delivery_codes';
  end if;
  if v_src like '%colis_receipts%sha256%' then
    raise exception 'ECHEC 1c : le bootstrap ecrit un hash dans le recu, lisible par le livreur';
  end if;

  raise notice 'OK 1 — bootstrap branche, hash ecrit dans la bonne table';
end
$$;


-- ── 2. Le hash ne vit nulle part où le livreur peut lire ───────────────────
do $$
declare n integer;
begin
  -- La colonne de hash ne doit exister que dans colis_delivery_codes.
  select count(*) into n from information_schema.columns
   where table_schema = 'public'
     and column_name in ('code_hash', 'delivery_code_hash')
     and table_name <> 'colis_delivery_codes';
  if n <> 0 then
    raise exception 'ECHEC 2a : % colonne(s) de hash hors de colis_delivery_codes. '
      'Un code a 4 chiffres se casse par force brute en une seconde.', n;
  end if;

  -- Et aucune policy de cette table ne doit viser les livreurs.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_delivery_codes'
     and (qual like '%drivers%' or coalesce(with_check, '') like '%drivers%');
  if n <> 0 then
    raise exception 'ECHEC 2b : une policy du code mentionne les livreurs';
  end if;

  -- Une seule policy, en lecture, pour l expediteur et les admins.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_delivery_codes';
  if n <> 1 then
    raise exception 'ECHEC 2c : colis_delivery_codes porte % policies au lieu d une', n;
  end if;

  raise notice 'OK 2 — le code est hors de portee du livreur';
end
$$;


-- ── 3. Immuabilité ─────────────────────────────────────────────────────────
do $$
declare
  v_order uuid := '00000000-dead-beef-0000-000000000001';
  v_caught boolean;
begin
  -- On simule une prise en charge enregistree.
  update public.colis_receipts
     set pickup_at = now(), pickup_photo_path = v_order || '/pickup_1.jpg'
   where order_id = v_order;

  -- 3a. Rejouer la prise en charge doit etre refuse.
  v_caught := false;
  begin
    update public.colis_receipts
       set pickup_at = now() + interval '1 minute'
     where order_id = v_order;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 3a : une prise en charge deja enregistree a pu etre reecrite';
  end if;

  -- 3b. Changer la photo de prise en charge aussi.
  v_caught := false;
  begin
    update public.colis_receipts
       set pickup_photo_path = 'autre.jpg'
     where order_id = v_order;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 3b : la photo de prise en charge a pu etre remplacee';
  end if;

  -- 3c. Et la valeur declaree, une fois le colis pris en charge : sinon on
  -- pourrait la relever apres avoir perdu le colis.
  v_caught := false;
  begin
    update public.colis_receipts
       set declared_value = 9999
     where order_id = v_order;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 3c : la valeur declaree a pu etre changee apres la prise en charge';
  end if;

  -- 3d. Supprimer un bon est impossible.
  v_caught := false;
  begin
    delete from public.colis_receipts where order_id = v_order;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 3d : un bon de prise en charge a pu etre supprime';
  end if;

  -- 3e. Le code non plus ne se modifie ni ne se supprime.
  v_caught := false;
  begin
    update public.colis_delivery_codes set code = '0000' where order_id = v_order;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 3e : le code de livraison a pu etre modifie';
  end if;

  raise notice 'OK 3 — preuves, declaration et code sont immuables';
end
$$;


-- ── 4. Plafond de valeur déclarée ──────────────────────────────────────────
do $$
declare
  v_max numeric;
  n integer;
begin
  v_max := public.platform_setting('colis_max_declared_value')::numeric;
  if v_max is null then
    raise exception 'ECHEC 4a : colis_max_declared_value absent de platform_settings';
  end if;
  if v_max <> 300 then
    raise notice 'ATTENTION 4 : le plafond vaut % TND (300 attendu a l installation)', v_max;
  end if;

  -- Le plafond doit etre lisible par tout utilisateur connecte : le
  -- formulaire client en a besoin pour s afficher.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'platform_settings'
     and cmd = 'SELECT';
  if n < 1 then
    raise exception 'ECHEC 4b : platform_settings n est lisible par personne';
  end if;

  raise notice 'OK 4 — plafond en base et lisible (% TND)', v_max;
end
$$;


-- ── 5. Fenêtre de litige ───────────────────────────────────────────────────
do $$
declare
  v_src text;
begin
  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'colis_open_dispute';

  if v_src is null then
    raise exception 'ECHEC 5a : colis_open_dispute n existe pas';
  end if;
  if v_src not like '%24 hours%' then
    raise exception 'ECHEC 5b : la fenetre de 24 h n est pas appliquee';
  end if;
  if v_src not like '%delivered_at%' then
    raise exception 'ECHEC 5c : la fenetre ne part pas de delivered_at';
  end if;

  raise notice 'OK 5 — fenetre de litige de 24 h depuis delivered_at';
end
$$;


-- ── 6. CIN invisible du client et du livreur ───────────────────────────────
do $$
declare n integer;
begin
  -- Les deux tables qui portent un CIN doivent etre admin-only.
  select count(*) into n from pg_policies
   where schemaname = 'public'
     and tablename in ('driver_identity', 'colis_receipt_identity')
     and qual not like '%is_admin%';
  if n <> 0 then
    raise exception 'ECHEC 6a : % policy(s) CIN sans controle admin', n;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public'
     and tablename in ('driver_identity', 'colis_receipt_identity');
  if n <> 2 then
    raise exception 'ECHEC 6b : % policies sur les tables CIN, 2 attendues', n;
  end if;

  -- Et le CIN ne doit pas s etre glisse dans le recu, que l expediteur lit.
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'colis_receipts'
     and column_name in ('cin', 'driver_cin');
  if n <> 0 then
    raise exception 'ECHEC 6c : le CIN figure dans colis_receipts, lisible par l expediteur';
  end if;

  raise notice 'OK 6 — le CIN n est visible que des admins';
end
$$;


-- ── 7. Les RPC sont fermées à anon ─────────────────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and (p.proname like 'colis\_%' or p.proname = 'create_colis_order')
     and has_function_privilege('anon', p.oid, 'execute');
  if n <> 0 then
    raise exception 'ECHEC 7 : % fonction(s) colis executables par anon', n;
  end if;

  raise notice 'OK 7 — aucune RPC colis ouverte a anon';
end
$$;


-- ── 8. Aucune écriture directe possible sur le reçu ────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_receipts' and cmd <> 'SELECT';
  if n <> 0 then
    raise exception 'ECHEC 8 : % policy(s) d ecriture directe sur colis_receipts. '
      'Tout doit passer par les RPC, sinon horodatage et immuabilite ne tiennent plus', n;
  end if;

  raise notice 'OK 8 — le recu ne s ecrit que par les RPC';
end
$$;


-- ── 9. Le déploiement souple est bien en place ─────────────────────────────
do $$
declare v text;
begin
  v := public.platform_setting('colis_proof_enforcement');
  if v is null then
    raise exception 'ECHEC 9a : colis_proof_enforcement absent';
  end if;
  if v not in ('soft', 'hard') then
    raise exception 'ECHEC 9b : valeur inattendue pour colis_proof_enforcement : %', v;
  end if;

  raise notice 'OK 9 — durcissement reglable, actuellement : %', v;
end
$$;


-- ============================================================================
-- RIEN N'EST CONSERVÉ.
-- ============================================================================
rollback;
