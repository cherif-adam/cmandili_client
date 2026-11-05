-- ============================================================================
-- Amana — Masquer les données des testeurs Google Play après le test fermé
--
-- NE PAS LANCER PENDANT LE TEST. À lancer dans le SQL Editor (projet
-- cmandili) quand le test fermé est fini, avant l'ouverture au public.
--
-- Les testeurs créent des boutiques (app partenaire) et des profils livreur.
-- Ce script les retire de la vue des vrais clients et du dispatch, SANS RIEN
-- SUPPRIMER :
--   boutiques  deleted_at = now(), is_open = false
--              -> les clients ne la voient plus (politique vendors_read :
--                 deleted_at IS NULL), aucune commande possible
--                 (enforce_venue_open) ; son propriétaire la voit toujours,
--                 les anciennes commandes aussi ;
--   articles   is_available = false (articles de ces boutiques) ;
--   livreurs   is_online = false, is_blocked = true
--              -> exclus du dispatch (next_eligible_driver,
--                 nearby_online_drivers).
-- Chaque valeur d'avant est notée dans backups.hidden_tester_data : la
-- partie « Annuler » en bas remet tout comme avant.
--
-- Jamais touchés : les comptes admin (profiles.is_admin), et les boutiques ou
-- profils livreur créés AVANT le début du test (date ci-dessous), même si
-- leur compte est dans la liste.
--
-- MODE D'EMPLOI
--   1. Remplir la liste des emails des testeurs (ceux de amana_client_list).
--   2. Lancer avec apercu = true : rien n'est modifié ; le tableau final
--      montre ce qui serait masqué.
--   3. Relire, puis relancer avec apercu = false : le tableau final montre ce
--      qui a été masqué, et l'heure du passage (pour annuler si besoin).
--
-- Limite connue : si un testeur livreur recharge un portefeuille bloqué pour
-- solde, le trigger enforce_prepaid_block peut remettre is_blocked = false.
-- Relancer ce script après toute recharge d'un testeur.
-- ============================================================================
begin;

create temp table hide_params on commit drop as
select
  -- 1. Les emails des testeurs, en minuscules ou non (exemple à remplacer) :
  array[
    'testeur1@example.com',
    'testeur2@example.com'
  ]::text[]                        as emails,
  -- Début du test fermé : rien de créé avant cette date n'est touché.
  timestamptz '2026-11-05 00:00:00+01' as debut,
  -- true = aperçu seulement ; false = masquer pour de vrai.
  true                             as apercu;

-- Les comptes visés : emails de la liste, jamais un admin.
create temp table hide_comptes on commit drop as
select u.id as user_id, lower(u.email) as email
  from auth.users u, hide_params p
 where lower(u.email) = any (select lower(e) from unnest(p.emails) e)
   and not exists (select 1 from public.profiles pr
                    where pr.id = u.id and pr.is_admin is true);

-- Ce qui serait masqué.
create temp table hide_cibles on commit drop as
select 'boutique'::text as type, v.id as row_id, v.name as nom, c.email, v.created_at
  from public.vendors v
  join hide_comptes c
    on c.user_id = v.owner_id
    or exists (select 1 from public.partners pa
                where pa.user_id = c.user_id and pa.entity_id::text = v.id::text)
  cross join hide_params p
 where v.deleted_at is null
   and v.created_at >= p.debut
union all
select 'livreur', d.id, coalesce(pr.full_name, '(sans nom)'), c.email, d.created_at
  from public.drivers d
  join hide_comptes c on c.user_id = d.user_id
  left join public.profiles pr on pr.id = d.user_id
  cross join hide_params p
 where d.created_at >= p.debut
   and (d.is_blocked is not true or d.is_online is true);

do $masquer$
declare
  v_apercu boolean;
  v_bad    integer;
begin
  select apercu into v_apercu from hide_params;
  select count(*) into v_bad from hide_params p, unnest(p.emails) e
   where e ilike '%@example.com' or btrim(e) = '';
  if v_bad > 0 and not v_apercu then
    raise exception 'Liste des testeurs pas remplie (adresses d''exemple) : rien n''est modifié';
  end if;
  if v_apercu then
    return;
  end if;

  create schema if not exists backups;
  revoke all on schema backups from public, anon, authenticated;
  create table if not exists backups.hidden_tester_data (
    id        bigserial primary key,
    run_at    timestamptz not null default now(),
    type      text not null,
    row_id    uuid not null,
    previous  jsonb not null
  );
  revoke all on table backups.hidden_tester_data from public, anon, authenticated;

  -- Boutiques
  insert into backups.hidden_tester_data (type, row_id, previous)
  select 'boutique', v.id, jsonb_build_object('deleted_at', v.deleted_at, 'is_open', v.is_open)
    from public.vendors v join hide_cibles t on t.type = 'boutique' and t.row_id = v.id;
  update public.vendors v
     set deleted_at = now(), is_open = false
    from hide_cibles t
   where t.type = 'boutique' and t.row_id = v.id;

  -- Articles de ces boutiques
  insert into backups.hidden_tester_data (type, row_id, previous)
  select 'article', i.id, jsonb_build_object('is_available', i.is_available)
    from public.vendor_items i join hide_cibles t on t.type = 'boutique' and t.row_id = i.vendor_id
   where i.is_available is true;
  update public.vendor_items i
     set is_available = false
    from hide_cibles t
   where t.type = 'boutique' and t.row_id = i.vendor_id and i.is_available is true;

  -- Livreurs
  insert into backups.hidden_tester_data (type, row_id, previous)
  select 'livreur', d.id, jsonb_build_object('is_online', d.is_online, 'is_blocked', d.is_blocked)
    from public.drivers d join hide_cibles t on t.type = 'livreur' and t.row_id = d.id;
  update public.drivers d
     set is_online = false, is_blocked = true
    from hide_cibles t
   where t.type = 'livreur' and t.row_id = d.id;
end
$masquer$;

-- Tableau final : ce qui serait masqué (aperçu) ou ce qui l'a été.
select t.type, t.nom, t.email, t.created_at,
       case when p.apercu then 'serait masqué (aperçu)' else 'masqué à ' || now()::text end as action,
       (select count(*) from hide_comptes) as comptes_trouves,
       (select cardinality(emails) from hide_params) as emails_dans_la_liste
  from hide_cibles t cross join hide_params p
 order by t.type, t.email, t.nom;

commit;

-- ============================================================================
-- ANNULER un passage (remplacer l'heure par celle du tableau final, puis
-- enlever les deux tirets au début de chaque ligne) :
--
-- begin;
-- update public.vendors v
--    set deleted_at = (h.previous ->> 'deleted_at')::timestamptz,
--        is_open    = (h.previous ->> 'is_open')::boolean
--   from backups.hidden_tester_data h
--  where h.type = 'boutique' and h.row_id = v.id and h.run_at = '2026-12-01 10:00:00+00';
-- update public.vendor_items i
--    set is_available = (h.previous ->> 'is_available')::boolean
--   from backups.hidden_tester_data h
--  where h.type = 'article' and h.row_id = i.id and h.run_at = '2026-12-01 10:00:00+00';
-- update public.drivers d
--    set is_online  = (h.previous ->> 'is_online')::boolean,
--        is_blocked = (h.previous ->> 'is_blocked')::boolean
--   from backups.hidden_tester_data h
--  where h.type = 'livreur' and h.row_id = d.id and h.run_at = '2026-12-01 10:00:00+00';
-- commit;
-- ============================================================================
