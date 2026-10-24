-- ============================================================================
-- CMANDILI — Harnais : le scan du contrat est-il réellement exigé ?
--
-- SÛR À LANCER EN PRODUCTION, par construction :
--   • une seule transaction, terminée par ROLLBACK ;
--   • les triggers sont COUPÉS le temps de fabriquer le jeu d'essai. Aucune
--     commande n'est insérée, donc notify_fcm_on_new_order n'a rien à envoyer,
--     mais on coupe quand même pour fabriquer les livreurs sans réveiller quoi
--     que ce soit ;
--   • aucun passage à 'delivered', donc aucun règlement ;
--   • aucune écriture dans le Stockage, qui n'est pas transactionnel : les
--     chemins de scan du jeu d'essai sont des chaînes, aucun fichier n'est
--     déposé ni supprimé.
--
-- Le réglage driver_verification_required est forcé à 'on' DANS la transaction
-- pour tester le durcissement, puis annulé avec le reste. La valeur de
-- production n'est jamais modifiée.
--
-- À lancer d'un bloc dans le SQL Editor, APRÈS
-- 20261015190000_driver_contract_scan_required.sql.
-- ============================================================================

begin;

-- ── 0. Préconditions ───────────────────────────────────────────────────────
-- Lancé avant la migration, ce harnais échouerait sur le test 2 avec un
-- message qui accuserait la fonction au lieu de dire « la migration n'a pas
-- tourné ». On le dit tout de suite.
do $$
declare
  n   integer;
  def text;
begin
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'driver_identity'
     and column_name = 'contract_scan_path';
  if n = 0 then
    raise exception
      'PRECONDITION : driver_identity.contract_scan_path est absente. Lancez 20261015103000_driver_verification_repair.sql.';
  end if;

  select pg_get_functiondef(p.oid) into def
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'driver_is_verified';
  if def is null then
    raise exception
      'PRECONDITION : driver_is_verified() est absente. 20261015090000 n a pas ete appliquee.';
  end if;
  if def not like '%contract_scan_path%' then
    raise exception
      'PRECONDITION : driver_is_verified() n exige pas encore le scan. Lancez 20261015190000_driver_contract_scan_required.sql, puis relancez ce harnais.';
  end if;

  raise notice 'OK 0 — preconditions reunies';
end
$$;


-- ── Triggers coupés pour le jeu d'essai ────────────────────────────────────
set local session_replication_role = replica;

do $$
begin
  if current_setting('session_replication_role') <> 'replica' then
    raise exception 'ARRET : impossible de couper les triggers (role=%)',
      current_setting('session_replication_role');
  end if;
end
$$;


-- ── Comptes auth réels pour le jeu d'essai ─────────────────────────────────
-- drivers.user_id a une FK vers auth.users, et on ne peut PAS la contourner :
-- session_replication_role = replica desactive aussi les contraintes (une FK
-- est un trigger systeme), donc un gen_random_uuid() passe a l'INSERT puis
-- echoue en 23503 au premier UPDATE apres le retablissement des triggers.
--
-- On emprunte donc des comptes existants qui ne sont PAS deja livreurs. Les
-- lignes drivers creees pour eux n'existent que le temps de la transaction.
--
-- Le filtre sur le wallet n'est pas cosmetique : nearby_online_drivers exige
-- coalesce(w.status, 'active') = 'active'. Emprunter un compte au wallet
-- suspendu ferait echouer le test 3 pour une raison qui n'a rien a voir avec
-- le scan.
create temp table _t_fixture (slot int primary key, user_id uuid) on commit drop;

do $$
declare n integer;
begin
  insert into _t_fixture (slot, user_id)
  select row_number() over (order by u.id), u.id
    from auth.users u
   where not exists (select 1 from public.drivers d where d.user_id = u.id)
     and coalesce((select w.status from public.wallets w where w.user_id = u.id), 'active') = 'active'
   limit 6;

  select count(*) into n from _t_fixture;
  if n < 6 then
    raise exception
      'PRECONDITION : il faut 6 comptes auth sans ligne drivers et au wallet actif, % trouve(s).', n;
  end if;

  raise notice 'Jeu d essai : 6 comptes auth empruntes';
end
$$;

-- Six livreurs, un par combinaison de pièces manquantes. Les identifiants
-- sont parlants : drivers.id n'a pas de FK, seul user_id doit etre reel.
--
--   ...c1  CIN + date + scan            -> VERIFIE
--   ...c2  CIN + date, scan absent      -> refuse (la nouvelle regle)
--   ...c3  CIN + date, scan = espaces   -> refuse (chaine vide != piece)
--   ...c4  CIN + scan, date absente     -> refuse (la date reste exigee)
--   ...c5  date + scan, CIN = espaces   -> refuse (le CIN reste exige)
--   ...c6  aucune ligne de dossier      -> refuse
do $$
declare
  v_c1 uuid := '00000000-5caf-f01d-0000-0000000000c1';
  v_c2 uuid := '00000000-5caf-f01d-0000-0000000000c2';
  v_c3 uuid := '00000000-5caf-f01d-0000-0000000000c3';
  v_c4 uuid := '00000000-5caf-f01d-0000-0000000000c4';
  v_c5 uuid := '00000000-5caf-f01d-0000-0000000000c5';
  v_c6 uuid := '00000000-5caf-f01d-0000-0000000000c6';
begin
  insert into public.drivers (id, user_id, is_online, is_blocked, current_lat, current_lng)
  values (v_c1, (select user_id from _t_fixture where slot = 1), true, false, 35.6781, 10.0963),
         (v_c2, (select user_id from _t_fixture where slot = 2), true, false, 35.6781, 10.0963),
         (v_c3, (select user_id from _t_fixture where slot = 3), true, false, 35.6781, 10.0963),
         (v_c4, (select user_id from _t_fixture where slot = 4), true, false, 35.6781, 10.0963),
         (v_c5, (select user_id from _t_fixture where slot = 5), true, false, 35.6781, 10.0963),
         (v_c6, (select user_id from _t_fixture where slot = 6), true, false, 35.6781, 10.0963);

  -- cin est NOT NULL sur driver_identity : le cas « pas de CIN » se joue donc
  -- avec des espaces (c5), et le cas « pas de dossier » en n'inserant rien
  -- du tout (c6).
  insert into public.driver_identity (driver_id, cin, contract_legalized_at, contract_scan_path)
  values (v_c1, 'TEST-CIN-C1', current_date, 'test/c1-1760000000000.pdf'),
         (v_c2, 'TEST-CIN-C2', current_date, null),
         (v_c3, 'TEST-CIN-C3', current_date, '   '),
         (v_c4, 'TEST-CIN-C4', null,         'test/c4-1760000000000.pdf'),
         (v_c5, '   ',         current_date, 'test/c5-1760000000000.pdf');

  raise notice 'Jeu d essai : 6 livreurs de test crees';
end
$$;

set local session_replication_role = default;


-- ── 1. Durcissement OFF : rien ne change pour personne ─────────────────────
-- C'est la garantie qui permet d'appliquer la migration en pleine journee.
do $$
declare v_id uuid;
begin
  update public.platform_settings set value = 'off'
   where key = 'driver_verification_required';

  foreach v_id in array array['00000000-5caf-f01d-0000-0000000000c2'::uuid,
                              '00000000-5caf-f01d-0000-0000000000c6'::uuid]
  loop
    if not public.driver_is_verified(v_id) then
      raise exception
        'ECHEC 1 : durcissement off, le livreur % devrait passer malgre son dossier incomplet', v_id;
    end if;
  end loop;

  raise notice 'OK 1 — durcissement off : aucun livreur n est bloque';
end
$$;


-- ── 2. Durcissement ON : les trois pièces, et seulement les trois ──────────
do $$
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';

  if not public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c1') then
    raise exception 'ECHEC 2a : CIN + date + scan devrait suffire';
  end if;

  -- Le coeur de la migration : ce livreur passait AVANT, il ne passe plus.
  if public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c2') then
    raise exception 'ECHEC 2b : le scan n est PAS exige — la migration n a rien change';
  end if;

  if public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c3') then
    raise exception 'ECHEC 2c : un chemin de scan vide est accepte comme une piece';
  end if;

  if public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c4') then
    raise exception 'ECHEC 2d : la date de legalisation n est plus exigee';
  end if;

  if public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c5') then
    raise exception 'ECHEC 2e : le CIN n est plus exige';
  end if;

  if public.driver_is_verified('00000000-5caf-f01d-0000-0000000000c6') then
    raise exception 'ECHEC 2f : un livreur sans dossier du tout est verifie';
  end if;

  if public.driver_is_verified(null) then
    raise exception 'ECHEC 2g : un driver_id null ne doit pas etre verifie';
  end if;

  raise notice 'OK 2 — CIN, date ET scan sont exiges, aucun des trois ne suffit seul';
end
$$;


-- ── 3. Le broadcast hérite du nouveau critère ──────────────────────────────
-- Test de COMPORTEMENT : nearby_online_drivers n'est pas modifiee par la
-- migration, elle appelle driver_is_verified(). C'est ce test qui prouve que
-- le resserrement arrive bien jusqu'a la porte d'entree des offres.
do $$
declare
  v_u1 uuid;
  v_u2 uuid;
  n integer;
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';

  select user_id into v_u1 from public.drivers
   where id = '00000000-5caf-f01d-0000-0000000000c1';
  select user_id into v_u2 from public.drivers
   where id = '00000000-5caf-f01d-0000-0000000000c2';

  select count(*) into n from public.nearby_online_drivers(35.6781, 10.0963, 7) r
   where r.user_id = v_u1;
  if n <> 1 then
    raise exception
      'ECHEC 3a : le livreur au dossier complet est absent du broadcast (% ligne/s)', n;
  end if;

  select count(*) into n from public.nearby_online_drivers(35.6781, 10.0963, 7) r
   where r.user_id = v_u2;
  if n <> 0 then
    raise exception 'ECHEC 3b : un livreur sans scan recoit encore les offres colis';
  end if;

  raise notice 'OK 3 — le broadcast ecarte le livreur dont il ne manque que le scan';
end
$$;


-- ── 4. Le waterfall et l'acceptation vérifient toujours ────────────────────
-- next_eligible_driver demande une commande pour etre exercee : on verifie sa
-- source, comme le harnais de la verification. Une regression ici viderait le
-- durcissement sans qu'aucune erreur ne se voie.
do $$
declare n integer;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('next_eligible_driver', 'nearby_online_drivers')
     and pg_get_functiondef(p.oid) like '%driver_is_verified%';
  if n <> 2 then
    raise exception 'ECHEC 4a : % fonction(s) d eligibilite sur 2 verifient le livreur', n;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim' and qual like '%driver_is_verified%';
  if n <> 1 then
    raise exception 'ECHEC 4b : la policy d acceptation ne verifie plus le livreur';
  end if;

  raise notice 'OK 4 — waterfall, broadcast et acceptation passent par la verification';
end
$$;


-- ── 5. Un livreur sans scan ne peut plus se mettre en ligne ────────────────
-- La regression a surveiller cote livreur : il etait autorise hier, il ne
-- l'est plus. On usurpe son JWT, sinon auth.uid() vaut NULL, la policy
-- drivers_update_own ne laisse passer aucune ligne, le trigger ne se
-- declenche pas et le test passerait a cote de ce qu'il mesure.
do $$
declare
  v_c2  uuid := '00000000-5caf-f01d-0000-0000000000c2';
  v_uid uuid;
  v_caught boolean := false;
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';
  update public.drivers set is_online = false where id = v_c2;

  select user_id into v_uid from public.drivers where id = v_c2;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_uid, 'role', 'authenticated')::text,
                     true);
  set local role authenticated;

  begin
    update public.drivers set is_online = true where id = v_c2;
  exception when others then
    v_caught := true;
  end;

  reset role;
  if not v_caught then
    raise exception 'ECHEC 5 : un livreur sans scan a pu passer en ligne';
  end if;

  raise notice 'OK 5 — le passage en ligne exige desormais le scan';
end
$$;


-- ── 6. Le livreur au dossier complet, lui, passe en ligne ──────────────────
-- Risque symetrique : un critere trop serre qui bloquerait TOUT LE MONDE
-- passerait les tests ci-dessus sans qu'on s'en apercoive.
do $$
declare
  v_c1  uuid := '00000000-5caf-f01d-0000-0000000000c1';
  v_uid uuid;
  n integer;
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';
  update public.drivers set is_online = false where id = v_c1;

  select user_id into v_uid from public.drivers where id = v_c1;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v_uid, 'role', 'authenticated')::text,
                     true);
  set local role authenticated;

  update public.drivers set is_online = true where id = v_c1;
  get diagnostics n = row_count;

  reset role;
  if n <> 1 then
    raise exception 'ECHEC 6 : le livreur au dossier COMPLET n a pas pu passer en ligne';
  end if;

  raise notice 'OK 6 — le dossier complet autorise toujours la mise en ligne';
exception when others then
  reset role;
  raise;
end
$$;


-- ── 7. Le scan reste réservé aux admins ────────────────────────────────────
do $$
declare n integer;
begin
  -- Le bucket porte une signature et une piece d'identite : jamais public.
  select count(*) into n from storage.buckets
   where id = 'driver-contracts' and public;
  if n <> 0 then
    raise exception 'ECHEC 7a : le bucket driver-contracts est public';
  end if;

  -- Le chemin du scan vit sur driver_identity, invisible hors admin.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'driver_identity'
     and qual not like '%is_admin%';
  if n <> 0 then
    raise exception 'ECHEC 7b : % policy(s) de driver_identity sans controle admin', n;
  end if;

  -- Et aucune policy de storage.objects n'ouvre ce bucket a un non-admin.
  select count(*) into n from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and (qual like '%driver-contracts%' or with_check like '%driver-contracts%')
     and coalesce(qual, '') || coalesce(with_check, '') not like '%is_admin%';
  if n <> 0 then
    raise exception 'ECHEC 7c : % policy(s) de storage ouvrent driver-contracts sans controle admin', n;
  end if;

  raise notice 'OK 7 — bucket prive, chemin invisible, policies admin-only';
end
$$;


-- ── 8. Rien n'est exécutable par anon ──────────────────────────────────────
-- Supabase accorde EXECUTE a anon sur toute nouvelle fonction du schema
-- public, et `create or replace` repasse par cette regle : c'est exactement ce
-- que la migration doit avoir revoque.
do $$
declare n integer;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('driver_is_verified', 'guard_drivers_column_scope',
                       'next_eligible_driver', 'nearby_online_drivers')
     and has_function_privilege('anon', p.oid, 'execute');
  if n <> 0 then
    raise exception 'ECHEC 8a : % fonction(s) executables par anon', n;
  end if;

  -- Et authenticated l'a toujours : l'app livreur appelle driver_is_verified
  -- pour savoir quoi afficher.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'driver_is_verified'
     and has_function_privilege('authenticated', p.oid, 'execute');
  if n <> 1 then
    raise exception 'ECHEC 8b : authenticated a perdu EXECUTE sur driver_is_verified';
  end if;

  raise notice 'OK 8 — anon n a rien, authenticated garde ce qu il lui faut';
end
$$;


-- ============================================================================
-- RIEN N'EST CONSERVÉ — y compris la valeur 'on' posée pendant les tests.
-- ============================================================================
rollback;
