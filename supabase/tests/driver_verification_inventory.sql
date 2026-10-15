-- ============================================================================
-- CMANDILI — Inventaire : qu'a réellement posé 20261015090000 ?
--
-- LECTURE SEULE. Aucun BEGIN, aucune écriture, rien à annuler. Collez,
-- exécutez, lisez le tableau.
--
-- Pourquoi ce fichier : 20261015090000 a rapporté « Success » alors que les
-- cinq colonnes de dossier manquent. Comme c'est une transaction unique, les
-- deux ne peuvent pas être vrais pour un même contenu — il faut donc voir
-- pièce par pièce ce qui est en place avant de décider quoi relancer.
--
-- Cet inventaire ne peut pas être fait à distance : les sondes REST ne
-- distinguent pas « objet absent » de « objet non exposé au rôle anon »
-- (testé : elles donnent un faux négatif sur des fonctions et des buckets
-- dont on sait qu'ils existent). Seule la base peut répondre.
-- ============================================================================

select 'colonne driver_identity.contract_signed_at'    as piece,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'driver_identity'
                  and column_name = 'contract_signed_at')               as en_place
union all
select 'colonne driver_identity.contract_legalized_at',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'driver_identity'
                  and column_name = 'contract_legalized_at')
union all
select 'colonne driver_identity.contract_scan_path',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'driver_identity'
                  and column_name = 'contract_scan_path')
union all
select 'colonne driver_identity.verified_at',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'driver_identity'
                  and column_name = 'verified_at')
union all
select 'colonne driver_identity.verified_by',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'driver_identity'
                  and column_name = 'verified_by')
union all
select 'reglage driver_verification_required',
       exists (select 1 from public.platform_settings
                where key = 'driver_verification_required')
union all
select 'fonction driver_is_verified',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'driver_is_verified')
union all
select 'fonction guard_drivers_column_scope',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'guard_drivers_column_scope')
union all
select 'trigger aa_guard_drivers_column_scope sur drivers',
       exists (select 1 from pg_trigger t
                 join pg_class c on c.oid = t.tgrelid
                 join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = 'drivers'
                  and t.tgname = 'aa_guard_drivers_column_scope'
                  and not t.tgisinternal)
union all
select 'verification dans next_eligible_driver',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'next_eligible_driver'
                  and pg_get_functiondef(p.oid) like '%driver_is_verified%')
union all
select 'verification dans nearby_online_drivers',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'nearby_online_drivers'
                  and pg_get_functiondef(p.oid) like '%driver_is_verified%')
union all
select 'is_blocked dans nearby_online_drivers (trou corrige)',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'nearby_online_drivers'
                  and pg_get_functiondef(p.oid) like '%is_blocked%')
union all
select 'verification dans la policy orders_driver_claim',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'orders'
                  and policyname = 'orders_driver_claim'
                  and qual like '%driver_is_verified%')
union all
select 'bucket driver-contracts',
       exists (select 1 from storage.buckets where id = 'driver-contracts')
order by en_place, piece;

-- ── Lecture du résultat ────────────────────────────────────────────────────
-- Les lignes `en_place = false` arrivent en premier.
--
--   • SEULES les 5 colonnes sont fausses  -> lancez
--     20261015103000_driver_verification_repair.sql, puis le harnais.
--   • TOUT est faux                       -> la migration n'a pas tourne du
--     tout ; relancez 20261015090000 en entier.
--   • Un melange                          -> relancez 20261015090000 en
--     entier. Il est idempotent, et chacun de ses revoke suit la creation de
--     sa fonction, donc le rejouer ne reouvre aucun droit a anon.
