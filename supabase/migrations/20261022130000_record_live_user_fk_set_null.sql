-- ============================================================================
-- CMANDILI / Amana — Enregistrer dans le dépôt l'état réel de trois clés
-- étrangères vers auth.users
--
-- CONSTAT (16-17/10/2026). Sur le live, ces trois liens ont changé HORS
-- dépôt (aucune migration, rien dans supabase_migrations.schema_migrations) :
--
--   orders.user_id                     CASCADE + NOT NULL   → SET NULL, nullable
--   payments.user_id                   NO ACTION + NOT NULL → SET NULL, nullable
--   loyalty_driver_payouts.customer_id NO ACTION + NOT NULL → SET NULL, nullable
--
-- Le dépôt, lui, dit encore l'inverse : cmandili_schema.sql crée orders avec
-- `user_id ... NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, et
-- 20260706171000_loyalty_program.sql crée customer_id en NOT NULL. Une base
-- montée depuis le dépôt (projet de test, restauration, nouvel
-- environnement) retrouverait CASCADE : supprimer un utilisateur y
-- effacerait ses commandes, et avec elles bons colis, paiements et litiges.
--
-- Cette migration rend le dépôt conforme au live, à l'identique :
--   FOREIGN KEY (...) REFERENCES auth.users(id) ON DELETE SET NULL,
--   colonne nullable, contrainte validée, non différable, mêmes noms.
--
-- Sur le live : AUCUN effet. Chaque lien n'est recréé que si sa définition
-- diffère, et une colonne n'est rendue nullable que si elle ne l'est pas.
-- Aucune donnée n'est modifiée. À la fin, l'état est vérifié : la migration
-- échoue (et s'annule) s'il ne correspond pas.
--
-- Note : la suppression de compte (20261017090000) ne supprime jamais la
-- ligne auth.users. Ces liens ne servent donc qu'en cas de suppression faite
-- à la main dans le dashboard ; SET NULL y garde la commande, sans plus
-- savoir à qui elle était.
-- ============================================================================

do $$
declare
  v_spec record;
  v_def  text;
begin
  for v_spec in
    select * from (values
      ('orders',                 'orders_user_id_fkey',                     'user_id'),
      ('payments',               'payments_user_id_fkey',                   'user_id'),
      ('loyalty_driver_payouts', 'loyalty_driver_payouts_customer_id_fkey', 'customer_id')
    ) as t(tbl, con, col)
  loop
    -- Colonne nullable : SET NULL ne peut pas écrire NULL dans une colonne
    -- NOT NULL (la suppression échouerait au lieu de garder la ligne).
    if exists (
         select 1 from pg_attribute
          where attrelid = format('public.%I', v_spec.tbl)::regclass
            and attname = v_spec.col
            and attnotnull
       ) then
      execute format('alter table public.%I alter column %I drop not null', v_spec.tbl, v_spec.col);
      raise notice '%.% : NOT NULL retiré', v_spec.tbl, v_spec.col;
    end if;

    select pg_get_constraintdef(c.oid) into v_def
      from pg_constraint c
     where c.conrelid = format('public.%I', v_spec.tbl)::regclass
       and c.conname = v_spec.con;

    if v_def is distinct from format(
         'FOREIGN KEY (%s) REFERENCES auth.users(id) ON DELETE SET NULL', v_spec.col) then
      execute format('alter table public.%I drop constraint if exists %I', v_spec.tbl, v_spec.con);
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references auth.users(id) on delete set null',
        v_spec.tbl, v_spec.con, v_spec.col);
      raise notice '%.% : recréée en ON DELETE SET NULL (était : %)', v_spec.tbl, v_spec.con, coalesce(v_def, 'absente');
    end if;
  end loop;
end
$$;

-- Vérification : exactement l'état du live.
do $$
declare
  v_bad text;
begin
  select string_agg(t.tbl || '.' || t.col, ', ') into v_bad
    from (values
      ('orders',                 'orders_user_id_fkey',                     'user_id'),
      ('payments',               'payments_user_id_fkey',                   'user_id'),
      ('loyalty_driver_payouts', 'loyalty_driver_payouts_customer_id_fkey', 'customer_id')
    ) as t(tbl, con, col)
   where not exists (
           select 1 from pg_constraint c
            where c.conrelid = format('public.%I', t.tbl)::regclass
              and c.conname = t.con
              and c.contype = 'f'
              and c.confrelid = 'auth.users'::regclass
              and c.confdeltype = 'n'
              and c.convalidated
              and not c.condeferrable)
      or exists (
           select 1 from pg_attribute a
            where a.attrelid = format('public.%I', t.tbl)::regclass
              and a.attname = t.col
              and a.attnotnull);
  if v_bad is not null then
    raise exception 'Clés étrangères vers auth.users différentes du live : %', v_bad;
  end if;
end
$$;
