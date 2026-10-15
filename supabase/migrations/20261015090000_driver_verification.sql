-- ============================================================================
-- CMANDILI — Vérification du livreur avant de travailler
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
-- (Rappel : cet en-tête est la formule par défaut de ces fichiers, pas un
--  statut. Seule la base fait foi.)
--
-- Un livreur ne reçoit, n'accepte et ne passe en ligne qu'une fois qu'un
-- admin a enregistré son CIN ET son contrat signé et légalisé à la baladiya.
--
-- ── POURQUOI PAS UN DRAPEAU SUR `drivers` ─────────────────────────────────
-- Parce qu'il serait auto-attribuable. La policy drivers_update_own n'a qu'un
-- USING (user_id = auth.uid()), SANS WITH CHECK, et aucun REVOKE ni garde-fou
-- de colonnes ne couvre la table : un livreur écrit donc n'importe quelle
-- colonne de sa propre ligne. Ce n'est pas théorique — la migration
-- 20261011120000 a dû ajouter protect_driver_rating() pour l'empêcher de se
-- noter lui-même.
--
-- La vérification vit donc dans driver_identity, déjà en place et déjà
-- admin-only (20261012090000). Un livreur ne voit même pas la table.
--
-- ── ET LE GARDE-FOU DE COLONNES ───────────────────────────────────────────
-- protect_driver_rating ne protège que deux colonnes, nommément. Section 5
-- le remplace par un garde deny-by-default sur le modèle de
-- aa_guard_orders_column_scope : tout ce qui n'est pas explicitement autorisé
-- est refusé, y compris les colonnes ajoutées plus tard.
--
-- ── DÉPLOIEMENT SOUPLE ────────────────────────────────────────────────────
-- platform_settings.driver_verification_required démarre à 'off'. Tant qu'il
-- y est, driver_is_verified() renvoie toujours vrai et RIEN ne change pour
-- les livreurs existants, qui n'ont pas encore de contrat enregistré. Le jour
-- où leurs dossiers sont remplis, passer la valeur à 'on' suffit.
--
-- ── TROIS TROUS PRÉEXISTANTS CORRIGÉS AU PASSAGE ──────────────────────────
-- Il fallait poser la vérification aux mêmes endroits, et ces trois-là
-- laissaient déjà passer un livreur BLOQUÉ :
--   1. nearby_online_drivers() (broadcast colis/facture) ne testait pas
--      is_blocked : un livreur bloqué recevait l'offre.
--   2. la policy orders_driver_claim ne testait que l'existence d'une ligne
--      drivers : un livreur bloqué pouvait accepter une commande du pool.
--   3. rien n'empêchait un livreur de passer is_online à true.
-- Corriger la vérification sans corriger ceux-là n'aurait rien donné : un
-- livreur non vérifié serait simplement passé par les portes restantes.
--
-- Le dispatch lui-même n'est PAS modifié : ni l'ordre du waterfall, ni les
-- paliers de broadcast, ni le calcul des commissions. On ajoute une condition
-- d'éligibilité, rien d'autre.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================

begin;

-- ── 1. Réglage du durcissement ─────────────────────────────────────────────

insert into public.platform_settings (key, value, description) values
  ('driver_verification_required', 'off',
   'on = un livreur non verifie (CIN + contrat legalise) ne recoit, n''accepte et ne passe en ligne pour aucune commande. off = comportement historique.')
on conflict (key) do nothing;


-- ── 2. Le dossier du livreur ───────────────────────────────────────────────
-- driver_identity existe depuis 20261012090000 et porte deja le CIN, avec une
-- RLS admin-only. On l'etend plutot que de creer une table de plus : c'est le
-- meme dossier, remis par la meme personne, au meme moment.

alter table public.driver_identity
  add column if not exists contract_signed_at    date,
  add column if not exists contract_legalized_at date,
  add column if not exists contract_scan_path    text,
  add column if not exists verified_at           timestamptz,
  add column if not exists verified_by           uuid;

comment on column public.driver_identity.contract_legalized_at is
  'Date de legalisation de signature a la baladiya. Avec le CIN, c''est le critere de verification. Le scan (contract_scan_path) reste facultatif.';


-- ── 3. Un livreur est-il vérifié ? ─────────────────────────────────────────
-- SECURITY DEFINER : la fonction lit driver_identity, qui est admin-only.
-- Sans cela, appelee depuis une policy pour le compte d'un livreur, elle
-- renverrait toujours faux.
--
-- STABLE et non VOLATILE : appelee plusieurs fois dans une meme requete
-- d'eligibilite, le planificateur peut la memoriser.

create or replace function public.driver_is_verified(p_driver_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_required text;
  v_ok       boolean;
begin
  if p_driver_id is null then
    return false;
  end if;

  -- Tant que le durcissement est 'off', tout le monde passe : les livreurs
  -- deja en poste n'ont pas encore de dossier.
  v_required := coalesce(public.platform_setting('driver_verification_required'), 'off');
  if v_required <> 'on' then
    return true;
  end if;

  select (i.cin is not null and btrim(i.cin) <> ''
          and i.contract_legalized_at is not null)
    into v_ok
    from public.driver_identity i
   where i.driver_id = p_driver_id;

  return coalesce(v_ok, false);
end;
$fn$;

-- Supabase accorde EXECUTE a anon sur toute nouvelle fonction du schema
-- public. `revoke from public` ne retire pas cet octroi nominatif.
revoke execute on function public.driver_is_verified(uuid) from public, anon;
-- Accordee a authenticated : l'app livreur l'appelle pour savoir quoi
-- afficher. Elle ne revele rien — un booleen sur son propre compte.
grant execute on function public.driver_is_verified(uuid) to authenticated;


-- ── 4. Les trois portes d'éligibilité ──────────────────────────────────────

-- 4a. Waterfall food/épicerie. Reprise a l'identique de la definition de
-- 20260613_driver_is_blocked.sql, avec la seule condition de verification en
-- plus. L'ordre (le plus proche d'abord) et le rayon ne changent pas.
create or replace function public.next_eligible_driver(
  p_order_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_passed UUID[];
  v_driver_id UUID;
BEGIN
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION),
    o.passed_driver_ids
  INTO v_lat, v_lng, v_passed
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
    RETURN NULL;
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.is_online = TRUE
    AND d.is_blocked = FALSE
    AND public.driver_is_verified(d.id)
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT (d.id = ANY(v_passed))
  ORDER BY public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) ASC
  LIMIT 1;

  RETURN v_driver_id;
END;
$$;

revoke execute on function public.next_eligible_driver(uuid, double precision) from public, anon, authenticated;


-- 4b. Broadcast colis/facture. Gagne la verification ET is_blocked, qui
-- manquait : un livreur bloque recevait l'offre.
-- Signature et type de retour REPRIS A L'IDENTIQUE de 20260512 : deux
-- colonnes, LIMIT 50, meme tri. CREATE OR REPLACE refuse un changement de
-- type de retour, et les appelants (la fonction push, le fan-out) lisent ces
-- deux colonnes-la. Seules les deux conditions sont ajoutees.
create or replace function public.nearby_online_drivers(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS TABLE(user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT
    d.user_id,
    public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  -- Left join with wallets. If no wallet exists, assume 'active'
  LEFT JOIN public.wallets w ON w.user_id = d.user_id
  WHERE d.is_online = true
    AND d.is_blocked = false
    AND public.driver_is_verified(d.id)
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND COALESCE(w.status, 'active') = 'active'
    AND public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 50;
$$;

revoke execute on function public.nearby_online_drivers(double precision, double precision, double precision) from public, anon, authenticated;


-- 4c. Acceptation. La policy ne testait que l'existence d'une ligne drivers :
-- ni is_blocked, ni verification. Le reste est repris a l'identique.
drop policy if exists "orders_driver_claim" on public.orders;
create policy "orders_driver_claim"
  on public.orders for update
  to authenticated
  using (
    driver_id is null
    and exists (
      select 1 from public.drivers d
       where d.user_id = auth.uid()
         and d.is_blocked = false
         and public.driver_is_verified(d.id)
    )
    and (
      assigned_driver_id in (select id from public.drivers where user_id = auth.uid())
      or (assigned_driver_id is null and status in ('pending', 'ready'))
    )
  )
  with check (
    driver_id in (select id from public.drivers where user_id = auth.uid())
  );


-- ── 5. Garde-fou de colonnes sur `drivers` ─────────────────────────────────
-- Remplace protect_driver_rating(), qui ne couvrait que deux colonnes
-- nommees. Deny-by-default, sur le modele de aa_guard_orders_column_scope :
-- une colonne ajoutee demain est protegee d'office.
--
-- COLONNES AUTORISEES A L'APP LIVREUR, et pourquoi :
--   is_online             passer en ligne / hors ligne (mais voir plus bas :
--                         refuse si non verifie)
--   current_lat           position, ecrite en continu par le suivi
--   current_lng           idem
--   last_location_update  horodatage de presence, ce que lit l'auto-offline
--   vehicle_type          renseignes par le livreur dans son profil
--   vehicle_make          idem
--   vehicle_model         idem
--   vehicle_plate         idem (figee dans le recu a la prise en charge, donc
--                         une modification ulterieure ne reecrit aucune preuve)
--   vehicle_color         idem
--
-- TOUT LE RESTE EST REFUSE pour authenticated/anon, notamment : is_blocked
-- (un livreur se debloquerait), rating et review_count (il se noterait),
-- user_id et id (il changerait d'identite), created_at, et toute colonne
-- future. Les ecritures admin passent par service_role, qui n'est ni
-- 'authenticated' ni 'anon' et sort donc en tete de fonction.

create or replace function public.guard_drivers_column_scope()
returns trigger
language plpgsql
as $fn$
declare
  v_allowed constant text[] := array[
    'is_online', 'current_lat', 'current_lng', 'last_location_update',
    'vehicle_type', 'vehicle_make', 'vehicle_model', 'vehicle_plate',
    'vehicle_color'
  ];
  v_col  text;
  v_old  jsonb := to_jsonb(old);
  v_new  jsonb := to_jsonb(new);
begin
  -- service_role, SECURITY DEFINER possedes par postgres, pg_cron : on sort.
  -- Meme logique que aa_guard_orders_column_scope.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  for v_col in select jsonb_object_keys(v_new) loop
    if v_new -> v_col is distinct from v_old -> v_col
       and not (v_col = any(v_allowed)) then
      raise exception
        'Colonne % non modifiable depuis l''application (livreur %)', v_col, old.id
        using errcode = '42501';
    end if;
  end loop;

  -- Passer en ligne exige d'etre verifie. Le refus est cote SERVEUR : un
  -- ancien APK qui n'affiche pas l'ecran d'attente est bloque quand meme.
  if coalesce(new.is_online, false) and not coalesce(old.is_online, false)
     and not public.driver_is_verified(old.id) then
    raise exception
      'Votre compte est en attente de verification. Fournissez votre CIN et votre contrat signe et legalise a l''equipe Amana.'
      using errcode = '42501';
  end if;

  return new;
end;
$fn$;

revoke execute on function public.guard_drivers_column_scope() from public, anon, authenticated;

-- protect_driver_rating est absorbe par le garde ci-dessus : rating et
-- review_count ne sont pas dans la liste blanche, donc refuses. On le laisse
-- en place -- il revertait silencieusement la ou le garde leve, et deux
-- filets valent mieux qu'un trou si l'un est retire par megarde.
drop trigger if exists aa_guard_drivers_column_scope on public.drivers;
create trigger aa_guard_drivers_column_scope
  before update on public.drivers
  for each row execute function public.guard_drivers_column_scope();


-- ── 6. Contrats scannés — bucket privé ─────────────────────────────────────
-- Facultatif (le critere est la case cochee + la date), mais quand il existe
-- il contient une signature et une piece d'identite : admins seuls.

insert into storage.buckets (id, name, public)
  values ('driver-contracts', 'driver-contracts', false)
  on conflict (id) do update set public = false;

drop policy if exists driver_contracts_admin_all on storage.objects;
create policy driver_contracts_admin_all
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'driver-contracts'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  )
  with check (
    bucket_id = 'driver-contracts'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );


-- ── 7. Garde-fous avant COMMIT ─────────────────────────────────────────────
do $$
declare n integer;
begin
  -- Le reglage existe et demarre a 'off' : sinon ce fichier bloquerait tous
  -- les livreurs en poste a l'instant ou il est lance.
  if coalesce(public.platform_setting('driver_verification_required'), '') <> 'off' then
    raise exception 'Abandon : driver_verification_required devrait valoir off a l installation (vaut %)',
      public.platform_setting('driver_verification_required');
  end if;

  -- Les trois portes appellent bien la verification.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('next_eligible_driver', 'nearby_online_drivers')
     and pg_get_functiondef(p.oid) like '%driver_is_verified%';
  if n <> 2 then
    raise exception 'Abandon : % fonction(s) d eligibilite sur 2 appellent driver_is_verified', n;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim'
     and qual like '%driver_is_verified%';
  if n <> 1 then
    raise exception 'Abandon : la policy d acceptation ne verifie pas le livreur';
  end if;

  -- Et les trois testent aussi is_blocked, qui manquait a deux d entre elles.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('next_eligible_driver', 'nearby_online_drivers')
     and pg_get_functiondef(p.oid) like '%is_blocked%';
  if n <> 2 then
    raise exception 'Abandon : % fonction(s) sur 2 testent is_blocked', n;
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim' and qual like '%is_blocked%';
  if n <> 1 then
    raise exception 'Abandon : la policy d acceptation ne teste pas is_blocked';
  end if;

  -- Le garde-fou de colonnes est en place.
  select count(*) into n from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relname = 'drivers'
     and t.tgname = 'aa_guard_drivers_column_scope' and not t.tgisinternal;
  if n <> 1 then
    raise exception 'Abandon : le garde-fou de colonnes sur drivers est absent';
  end if;

  -- Aucune des nouvelles fonctions n est executable par anon.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('driver_is_verified', 'guard_drivers_column_scope',
                       'next_eligible_driver', 'nearby_online_drivers')
     and has_function_privilege('anon', p.oid, 'execute');
  if n <> 0 then
    raise exception 'Abandon : % fonction(s) encore executables par anon', n;
  end if;

  -- Le bucket des contrats est prive.
  select count(*) into n from storage.buckets
   where id = 'driver-contracts' and public;
  if n <> 0 then
    raise exception 'Abandon : le bucket driver-contracts est public';
  end if;

  raise notice 'OK — verification livreur en place, durcissement off';
end
$$;

commit;
