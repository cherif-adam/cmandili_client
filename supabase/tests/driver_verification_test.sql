-- ============================================================================
-- CMANDILI — Harnais de test de la vérification livreur
--
-- SÛR À LANCER EN PRODUCTION, par construction :
--   • une seule transaction, terminée par ROLLBACK ;
--   • les triggers sont COUPÉS le temps de fabriquer le jeu d'essai. Insérer
--     une commande en status='ready' declenche notify_fcm_on_new_order, qui
--     envoie par net.http_post une VRAIE offre de course a de VRAIS livreurs
--     (voir 20260815120000). Ce harnais n'insere pas de commande, mais il
--     coupe quand meme pour fabriquer ses livreurs sans reveiller quoi que ce
--     soit ;
--   • aucun passage a 'delivered', donc aucun reglement ;
--   • aucune ecriture dans le Stockage, qui n'est pas transactionnel.
--
-- Le réglage driver_verification_required est forcé à 'on' DANS la
-- transaction pour tester le durcissement, puis annulé avec le reste. La
-- valeur de production n'est jamais modifiee.
--
-- À lancer d'un bloc dans le SQL Editor, APRÈS 20261015090000.
-- ============================================================================

begin;

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

-- Trois livreurs de test, aux identifiants reconnaissables.
--   dead-beef...01  verifie    : CIN + contrat legalise
--   dead-beef...02  sans CIN
--   dead-beef...03  CIN mais contrat manquant
do $$
declare
  v_d1 uuid := '00000000-dead-beef-0000-0000000000d1';
  v_d2 uuid := '00000000-dead-beef-0000-0000000000d2';
  v_d3 uuid := '00000000-dead-beef-0000-0000000000d3';
begin
  insert into public.drivers (id, user_id, is_online, is_blocked, current_lat, current_lng)
  values (v_d1, gen_random_uuid(), true, false, 35.6781, 10.0963),
         (v_d2, gen_random_uuid(), true, false, 35.6781, 10.0963),
         (v_d3, gen_random_uuid(), true, false, 35.6781, 10.0963);

  insert into public.driver_identity (driver_id, cin, contract_legalized_at)
  values (v_d1, 'TEST-CIN-1', current_date);

  insert into public.driver_identity (driver_id, cin)
  values (v_d3, 'TEST-CIN-3');

  raise notice 'Jeu d''essai : 3 livreurs de test crees';
end
$$;

set local session_replication_role = default;


-- ── 1. driver_is_verified, durcissement OFF ────────────────────────────────
-- Comportement historique : tout le monde passe, y compris sans dossier.
do $$
begin
  update public.platform_settings set value = 'off'
   where key = 'driver_verification_required';

  if not public.driver_is_verified('00000000-dead-beef-0000-0000000000d2') then
    raise exception 'ECHEC 1 : durcissement off, un livreur sans CIN devrait passer';
  end if;

  raise notice 'OK 1 — durcissement off : comportement historique preserve';
end
$$;


-- ── 2. driver_is_verified, durcissement ON ─────────────────────────────────
do $$
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';

  if not public.driver_is_verified('00000000-dead-beef-0000-0000000000d1') then
    raise exception 'ECHEC 2a : un livreur avec CIN et contrat devrait etre verifie';
  end if;
  if public.driver_is_verified('00000000-dead-beef-0000-0000000000d2') then
    raise exception 'ECHEC 2b : un livreur SANS CIN ne doit pas etre verifie';
  end if;
  if public.driver_is_verified('00000000-dead-beef-0000-0000000000d3') then
    raise exception 'ECHEC 2c : un livreur sans contrat legalise ne doit pas etre verifie';
  end if;
  if public.driver_is_verified(null) then
    raise exception 'ECHEC 2d : un driver_id null ne doit pas etre verifie';
  end if;

  raise notice 'OK 2 — CIN ET contrat sont tous deux exiges';
end
$$;


-- ── 3. Les trois portes appellent la vérification ──────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('next_eligible_driver', 'nearby_online_drivers')
     and pg_get_functiondef(p.oid) like '%driver_is_verified%';
  if n <> 2 then
    raise exception 'ECHEC 3a : % fonction(s) d eligibilite sur 2 verifient le livreur', n;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim' and qual like '%driver_is_verified%';
  if n <> 1 then
    raise exception 'ECHEC 3b : la policy d acceptation ne verifie pas le livreur';
  end if;

  raise notice 'OK 3 — waterfall, broadcast et acceptation verifient le livreur';
end
$$;


-- ── 4. Le broadcast exclut réellement un livreur non vérifié ───────────────
-- Test de comportement et non de source : on interroge la fonction.
do $$
declare
  v_d1 uuid := '00000000-dead-beef-0000-0000000000d1';
  v_u1 uuid;
  v_u2 uuid;
  n integer;
begin
  update public.platform_settings set value = 'on'
   where key = 'driver_verification_required';

  select user_id into v_u1 from public.drivers where id = v_d1;
  select user_id into v_u2 from public.drivers
   where id = '00000000-dead-beef-0000-0000000000d2';

  select count(*) into n from public.nearby_online_drivers(35.6781, 10.0963, 7) r
   where r.user_id = v_u1;
  if n <> 1 then
    raise exception 'ECHEC 4a : le livreur verifie devrait etre dans le broadcast';
  end if;

  select count(*) into n from public.nearby_online_drivers(35.6781, 10.0963, 7) r
   where r.user_id = v_u2;
  if n <> 0 then
    raise exception 'ECHEC 4b : un livreur NON verifie est dans le broadcast';
  end if;

  raise notice 'OK 4 — le broadcast ecarte le livreur non verifie';
end
$$;


-- ── 5. Un livreur bloqué est écarté partout ────────────────────────────────
-- Les trois trous preexistants : le broadcast et l'acceptation ne testaient
-- pas is_blocked.
do $$
declare
  v_d1 uuid := '00000000-dead-beef-0000-0000000000d1';
  v_u1 uuid;
  n integer;
begin
  update public.drivers set is_blocked = true where id = v_d1;
  select user_id into v_u1 from public.drivers where id = v_d1;

  select count(*) into n from public.nearby_online_drivers(35.6781, 10.0963, 7) r
   where r.user_id = v_u1;
  if n <> 0 then
    raise exception 'ECHEC 5a : un livreur BLOQUE est encore dans le broadcast';
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim' and qual like '%is_blocked%';
  if n <> 1 then
    raise exception 'ECHEC 5b : la policy d acceptation ne teste pas is_blocked';
  end if;

  update public.drivers set is_blocked = false where id = v_d1;
  raise notice 'OK 5 — le livreur bloque est ecarte du broadcast et de l acceptation';
end
$$;


-- ── 6. Garde-fou de colonnes sur drivers ───────────────────────────────────
-- Le trigger sort en tete quand current_user n'est ni authenticated ni anon :
-- ici nous sommes postgres, donc il ne se declenche pas. On verifie sa
-- presence et sa liste blanche dans le source, puis on l'exerce reellement
-- en prenant le role authenticated.
do $$
declare n integer; v_src text; v_col text;
begin
  select count(*) into n from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relname = 'drivers'
     and t.tgname = 'aa_guard_drivers_column_scope' and not t.tgisinternal;
  if n <> 1 then
    raise exception 'ECHEC 6a : le garde-fou de colonnes est absent de drivers';
  end if;

  select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'guard_drivers_column_scope';

  -- Commentaires retires : le bloc d'explication cite justement is_blocked,
  -- rating et review_count comme colonnes REFUSEES. Sans depouillage, le
  -- test echouerait sur sa propre documentation.
  v_src := regexp_replace(v_src, '--[^' || chr(10) || ']*', '', 'g');

  -- La liste blanche ne doit contenir aucune colonne sensible.
  if v_src like '%''is_blocked''%' then
    raise exception 'ECHEC 6b : is_blocked figure dans la liste blanche';
  end if;
  if v_src like '%''rating''%' or v_src like '%''review_count''%' then
    raise exception 'ECHEC 6c : rating/review_count figurent dans la liste blanche';
  end if;
  if v_src like '%''user_id''%' then
    raise exception 'ECHEC 6d : user_id figure dans la liste blanche';
  end if;

  -- Et les colonnes dont l'app a reellement besoin y sont bien : sans elles
  -- le livreur ne pourrait plus passer en ligne ni envoyer sa position, ce
  -- qui serait un garde-fou pire que le trou qu'il bouche.
  foreach v_col in array array['is_online', 'current_lat', 'current_lng',
                               'last_location_update', 'vehicle_plate']
  loop
    if v_src not like '%''' || v_col || '''%' then
      raise exception 'ECHEC 6e : % manque a la liste blanche, l app livreur serait cassee', v_col;
    end if;
  end loop;

  raise notice 'OK 6 — garde-fou present, liste blanche juste';
end
$$;


-- ── 7. Le garde-fou refuse réellement une écriture interdite ───────────────
-- On prend le role authenticated, celui que le trigger controle.
do $$
declare
  v_d1 uuid := '00000000-dead-beef-0000-0000000000d1';
  v_caught boolean;
begin
  set local role authenticated;

  -- 7a. Se debloquer soi-meme.
  v_caught := false;
  begin
    update public.drivers set is_blocked = false where id = v_d1;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 7a : un livreur a pu ecrire is_blocked';
  end if;

  -- 7b. Se noter soi-meme.
  v_caught := false;
  begin
    update public.drivers set rating = 5 where id = v_d1;
  exception when others then
    v_caught := true;
  end;
  if not v_caught then
    raise exception 'ECHEC 7b : un livreur a pu ecrire rating';
  end if;

  reset role;
  raise notice 'OK 7 — is_blocked et rating sont refuses a authenticated';
exception when others then
  reset role;
  raise;
end
$$;


-- ── 8. Le CIN reste invisible des non-admins ───────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'driver_identity'
     and qual not like '%is_admin%';
  if n <> 0 then
    raise exception 'ECHEC 8a : % policy(s) de driver_identity sans controle admin', n;
  end if;

  -- Le contrat scanne ne doit pas etre public.
  select count(*) into n from storage.buckets
   where id = 'driver-contracts' and public;
  if n <> 0 then
    raise exception 'ECHEC 8b : le bucket des contrats est public';
  end if;

  raise notice 'OK 8 — CIN et contrats reserves aux admins';
end
$$;


-- ── 9. Rien n'est executable par anon ──────────────────────────────────────
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
    raise exception 'ECHEC 9 : % fonction(s) executables par anon', n;
  end if;

  raise notice 'OK 9 — aucune fonction ouverte a anon';
end
$$;


-- ============================================================================
-- RIEN N'EST CONSERVÉ — y compris la valeur 'on' posée pendant les tests.
-- ============================================================================
rollback;
