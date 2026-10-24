-- ============================================================================
-- CMANDILI — Le scan du contrat devient une pièce obligatoire
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- CE QUE ÇA CHANGE. driver_is_verified() exigeait deux pièces : le CIN et la
-- date de légalisation à la baladiya. Le scan du contrat était explicitement
-- facultatif — « une pièce jointe, pas la preuve ». Il devient la troisième
-- pièce obligatoire. Un livreur n'est vérifié que si les trois sont là :
--
--   1. cin                   — saisi en présentiel au recrutement
--   2. contract_legalized_at — date de légalisation de signature
--   3. contract_scan_path    — le document lui-même, dans le bucket privé
--
-- POURQUOI. Une date saisie à la main n'atteste rien : elle dit qu'un admin a
-- tapé une date. Devant un litige, un assureur ou une plainte, la pièce qui
-- compte est le document signé et tamponné. Tant que le scan restait
-- facultatif, « vérifié » voulait dire « quelqu'un a coché une case ».
--
-- EFFET IMMÉDIAT : AUCUN, tant que platform_settings.driver_verification_required
-- vaut 'off' — driver_is_verified() renvoie alors vrai pour tout le monde,
-- avant même de regarder le dossier. Ce fichier resserre la DÉFINITION de
-- « vérifié », pas la date à laquelle elle s'applique.
--
-- GARDE-FOU. Si le durcissement est déjà 'on', ce fichier REFUSE de s'appliquer
-- et vous dit combien de livreurs perdraient leur vérification à la seconde du
-- commit. Resserrer le critère sous un durcissement actif, c'est mettre des
-- livreurs à l'arrêt en pleine tournée, sans préavis et sans qu'ils puissent
-- rien y faire : le scan est déposé par l'ADMIN, pas par eux.
--
-- CE QUI NE CHANGE PAS :
--   • le dispatch — ni l'ordre du waterfall, ni les paliers de broadcast, ni
--     le calcul des commissions ;
--   • les trois portes d'éligibilité (next_eligible_driver,
--     nearby_online_drivers, policy orders_driver_claim) : elles appellent
--     driver_is_verified() et héritent du nouveau critère sans être touchées ;
--   • le message d'erreur du garde-fou de mise en ligne, qui demande au
--     livreur son CIN et son contrat signé et légalisé « à l'équipe Amana ».
--     Il reste exact : le livreur remet le papier, l'équipe le scanne. Lui
--     réclamer un scan serait lui demander une chose qu'il ne peut pas faire.
--   • driver_identity reste admin-only en RLS. L'app livreur ne lit jamais
--     ces colonnes.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================

begin;

-- ── 1. Refus si le durcissement est actif ──────────────────────────────────
-- Compté sur les colonnes, pas via driver_is_verified() : sous 'off' la
-- fonction renvoie vrai pour tout le monde et ne dirait rien du dossier réel.
do $$
declare
  v_required text;
  v_at_risk  integer;
  v_missing  integer;
begin
  v_required := coalesce(public.platform_setting('driver_verification_required'), 'off');

  select count(*) into v_at_risk
    from public.driver_identity i
   where i.cin is not null and btrim(i.cin) <> ''
     and i.contract_legalized_at is not null
     and (i.contract_scan_path is null or btrim(i.contract_scan_path) = '');

  if v_required = 'on' and v_at_risk > 0 then
    raise exception
      'Abandon : le durcissement est ON et % livreur(s) verifie(s) n ont pas de scan. Ils seraient bloques au commit. Passez driver_verification_required a off, deposez les scans, puis relancez.',
      v_at_risk;
  end if;

  select count(*) into v_missing
    from public.drivers d
    left join public.driver_identity i on i.driver_id = d.id
   where i.contract_scan_path is null or btrim(i.contract_scan_path) = '';

  raise notice 'Scans manquants : % livreur(s) sur %.',
    v_missing, (select count(*) from public.drivers);
  if v_at_risk > 0 then
    raise notice '  dont % qui etaient vus comme verifies avec le seul CIN + date.', v_at_risk;
  end if;
end
$$;


-- ── 2. Le critère passe à trois pièces ─────────────────────────────────────
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
  -- deja en poste n'ont pas encore de dossier complet.
  v_required := coalesce(public.platform_setting('driver_verification_required'), 'off');
  if v_required <> 'on' then
    return true;
  end if;

  -- Les TROIS pieces. Une chaine vide ne vaut pas une piece : une colonne
  -- texte remplie d'espaces passerait un simple `is not null`.
  select (i.cin is not null and btrim(i.cin) <> ''
          and i.contract_legalized_at is not null
          and i.contract_scan_path is not null and btrim(i.contract_scan_path) <> '')
    into v_ok
    from public.driver_identity i
   where i.driver_id = p_driver_id;

  return coalesce(v_ok, false);
end;
$fn$;

comment on function public.driver_is_verified(uuid) is
  'Un livreur est verifie s il a les trois pieces : CIN, date de legalisation a la baladiya, et scan du contrat dans le bucket prive driver-contracts. Renvoie toujours vrai tant que platform_settings.driver_verification_required vaut off.';

comment on column public.driver_identity.contract_scan_path is
  'Chemin du scan du contrat signe et legalise, dans le bucket PRIVE driver-contracts (<driver_id>/<timestamp>.<ext>). Troisieme piece obligatoire de la verification. Un remplacement ecrit un NOUVEAU chemin : l ancien fichier reste dans le bucket, jamais ecrase.';

-- Supabase accorde EXECUTE a anon sur toute nouvelle fonction du schema
-- public, et `create or replace` repasse par cette regle. `revoke from public`
-- ne retire pas cet octroi nominatif : il faut nommer anon.
revoke execute on function public.driver_is_verified(uuid) from public, anon;
-- Accordee a authenticated : l'app livreur l'appelle pour savoir quoi
-- afficher. Elle ne revele rien — un booleen sur son propre compte.
grant execute on function public.driver_is_verified(uuid) to authenticated;


-- ── 3. Garde-fous avant COMMIT ─────────────────────────────────────────────
do $$
declare
  n     integer;
  def   text;
  v_oid oid;
begin
  select p.oid, pg_get_functiondef(p.oid) into v_oid, def
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'driver_is_verified';
  if def is null then
    raise exception 'Abandon : driver_is_verified a disparu';
  end if;

  -- Les trois pieces sont bien exigees.
  if def not like '%contract_scan_path%' then
    raise exception 'Abandon : driver_is_verified n exige pas le scan';
  end if;
  if def not like '%contract_legalized_at%' then
    raise exception 'Abandon : driver_is_verified n exige plus la date de legalisation';
  end if;
  if def not like '%i.cin%' then
    raise exception 'Abandon : driver_is_verified n exige plus le CIN';
  end if;

  -- anon ne peut pas l'appeler. has_function_privilege et non
  -- information_schema : il repond aussi vrai quand le droit arrive par un
  -- octroi a PUBLIC, c'est-a-dire exactement le cas que le revoke vise.
  if has_function_privilege('anon', v_oid, 'execute') then
    raise exception 'Abandon : anon peut encore executer driver_is_verified';
  end if;

  -- authenticated l'a toujours : sans ça l'app livreur n'affiche plus rien.
  if not has_function_privilege('authenticated', v_oid, 'execute') then
    raise exception 'Abandon : authenticated a perdu EXECUTE sur driver_is_verified';
  end if;

  -- Les trois portes appellent toujours la verification. Elles ne sont pas
  -- modifiees ici, mais une regression a cet endroit viderait le durcissement
  -- de tout effet sans qu'aucune erreur ne se voie.
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
    raise exception 'Abandon : la policy orders_driver_claim ne verifie plus le livreur';
  end if;

  -- Le reglage n'a pas ete touche par ce fichier.
  if coalesce(public.platform_setting('driver_verification_required'), '') <> 'off' then
    raise notice 'ATTENTION : driver_verification_required vaut % — le nouveau critere s applique DEJA.',
      public.platform_setting('driver_verification_required');
  end if;

  -- Le bucket des contrats est toujours prive : il contient une signature et
  -- une piece d'identite.
  select count(*) into n from storage.buckets
   where id = 'driver-contracts' and public;
  if n <> 0 then
    raise exception 'Abandon : le bucket driver-contracts est public';
  end if;

  raise notice 'OK — le scan du contrat est desormais exige par driver_is_verified.';
end
$$;

commit;
