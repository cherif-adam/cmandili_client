-- ============================================================================
-- CMANDILI — Rattrapage : colonnes manquantes sur driver_identity
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- CE QUI S'EST PASSÉ : 20261015090000 a rapporté « Success », mais les cinq
-- colonnes que sa section 2 ajoute à driver_identity sont absentes en
-- production. Vérifié colonne par colonne : seules driver_id, cin, updated_at
-- et updated_by existent — c'est-à-dire exactement la table telle que
-- 20261012090000 l'avait créée, sans aucun ajout.
--
-- Comme 20261015090000 est une transaction unique (begin ... commit), « tout
-- a réussi » et « ces colonnes manquent » ne peuvent pas être vrais en même
-- temps pour un seul et même fichier. L'explication la plus simple est que le
-- contenu exécuté n'était pas celui du fichier commité — une copie plus
-- ancienne, ou une sélection partielle dans l'éditeur.
--
-- CE FICHIER NE DEVINE PAS. Il ajoute les colonnes si elles manquent, puis il
-- INVENTORIE tout ce que 20261015090000 devait poser et vous dit, pièce par
-- pièce, ce qui est là et ce qui ne l'est pas. Si l'inventaire signale autre
-- chose que les colonnes, relancez 20261015090000 en entier : il est
-- idempotent, et ses revoke suivent chaque création de fonction, donc le
-- rejouer ne réouvre aucun droit.
--
-- Aucun nom de colonne ne change : l'audit croisé migration / harnais / route
-- admin / panneau / page livreurs ne montre aucune divergence. L'app livreur
-- ne lit jamais ces colonnes — driver_identity est admin-only.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================

begin;

-- ── 1. Les colonnes manquantes ─────────────────────────────────────────────
alter table public.driver_identity
  add column if not exists contract_signed_at    date,
  add column if not exists contract_legalized_at date,
  add column if not exists contract_scan_path    text,
  add column if not exists verified_at           timestamptz,
  add column if not exists verified_by           uuid;

comment on column public.driver_identity.contract_legalized_at is
  'Date de legalisation de signature a la baladiya. Avec le CIN, c''est le critere de verification. Le scan (contract_scan_path) reste facultatif.';


-- ── 2. Garde-fou : les colonnes sont bien là ───────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'driver_identity'
     and column_name in ('contract_signed_at', 'contract_legalized_at',
                         'contract_scan_path', 'verified_at', 'verified_by');
  if n <> 5 then
    raise exception 'Abandon : % colonne(s) sur 5 presentes apres l ALTER', n;
  end if;
  raise notice 'OK — les 5 colonnes de dossier sont en place';
end
$$;


-- ── 3. Inventaire du reste de 20261015090000 ───────────────────────────────
-- Ne lève rien : c'est un constat, pas un test. Lisez les NOTICE.
do $$
declare
  v_missing text[] := '{}';
  n integer;
begin
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'driver_is_verified';
  if n = 0 then v_missing := v_missing || 'fonction driver_is_verified'; end if;

  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'guard_drivers_column_scope';
  if n = 0 then v_missing := v_missing || 'fonction guard_drivers_column_scope'; end if;

  select count(*) into n from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relname = 'drivers'
     and t.tgname = 'aa_guard_drivers_column_scope' and not t.tgisinternal;
  if n = 0 then v_missing := v_missing || 'trigger aa_guard_drivers_column_scope'; end if;

  select count(*) into n from public.platform_settings
   where key = 'driver_verification_required';
  if n = 0 then v_missing := v_missing || 'reglage driver_verification_required'; end if;

  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'next_eligible_driver'
     and pg_get_functiondef(p.oid) like '%driver_is_verified%';
  if n = 0 then v_missing := v_missing || 'verification dans next_eligible_driver'; end if;

  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname = 'nearby_online_drivers'
     and pg_get_functiondef(p.oid) like '%driver_is_verified%';
  if n = 0 then v_missing := v_missing || 'verification dans nearby_online_drivers'; end if;

  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'orders'
     and policyname = 'orders_driver_claim' and qual like '%driver_is_verified%';
  if n = 0 then v_missing := v_missing || 'verification dans orders_driver_claim'; end if;

  select count(*) into n from storage.buckets where id = 'driver-contracts';
  if n = 0 then v_missing := v_missing || 'bucket driver-contracts'; end if;

  if array_length(v_missing, 1) is null then
    raise notice 'INVENTAIRE : tout le reste de 20261015090000 est en place.';
  else
    raise notice 'INVENTAIRE : % piece(s) MANQUANTE(S) -> relancez 20261015090000 en entier.',
      array_length(v_missing, 1);
    for n in 1 .. array_length(v_missing, 1) loop
      raise notice '  manquant : %', v_missing[n];
    end loop;
  end if;
end
$$;

commit;
