-- ============================================================================
-- CMANDILI / Amana — delete_my_account() passe par la suppression de compte
--
-- NON EXÉCUTÉE. À lancer APRÈS 20261017090000_account_deletion.sql et
-- 20261022130000_record_live_user_fk_set_null.sql.
--
-- CONSTAT (25/10/2026, sur le live) :
--   • public.delete_my_account() existe : c'est la version CLIENT de
--     20261017120000, lancée une fois depuis le SQL Editor (corps identique
--     octet pour octet, fins de ligne CRLF). Elle supprime la ligne
--     auth.users de l'appelant, sans ré-authentification, sans autre blocage
--     que « commande en cours », et tout compte connecté peut l'appeler :
--     un partenaire y perdrait ses règlements, un livreur son solde
--     (settlements et wallets sont encore en CASCADE sur le live).
--   • 20261018090000 (version livreur) n'a jamais été lancée.
--   • Le bloc 1 de 20261017120000 est ce qui a passé orders.user_id,
--     payments.user_id et loyalty_driver_payouts.customer_id en SET NULL
--     (état enregistré par 20261022130000, conforme à la suppression de
--     compte : la ligne auth.users n'est jamais supprimée).
--   • Des builds appellent delete_my_account() : client 1.0.2+5 (depuis le
--     commit 4ad2a9a) et livreur depuis 79ae1f5 (version restée 1.0.0+1).
--     Rien dans le dépôt ne dit s'ils sont sur Google Play. Dans le doute la
--     fonction reste : la supprimer casserait le bouton de ces builds.
--
-- CE QUE FAIT CETTE MIGRATION
--   1. delete_my_account() garde son nom et sa signature (RETURNS void, ce
--      que ces builds appellent) mais ne supprime plus rien elle-même. Elle
--      applique la règle de ré-authentification de l'Edge Function
--      delete-account (dernière connexion de moins de 5 minutes, d'après le
--      claim amr), puis appelle account_deletion_execute() : mêmes
--      blocages, même anonymisation, même bannissement, même journal, mêmes
--      purges à 30 jours et à 5 ans.
--      Ce que SQL ne peut pas faire reste dû : la suppression « soft » GoTrue
--      et le retrait des fichiers du Stockage. Le journal reste en
--      'auth_pending', avec dans `error` la liste des fichiers, pour que
--      l'admin termine.
--      Un refus remonte en erreur avec les mots que ces builds cherchent
--      dans le message (active_order, negative_balance).
--   2. Les clés étrangères RESTRICT de 20261017090000 sont ré-affirmées. Sur
--      une base montée depuis le dépôt, 20261017120000 passe APRÈS
--      20261017090000 et les remet en SET NULL (en retirant NOT NULL) : sans
--      ce bloc, supprimer un utilisateur à la main détacherait de nouveau
--      règlements, portefeuilles, fiches livreur et partenaire, avis. Sur le
--      live, où 20261017120000 a tourné avant : aucun effet.
--
-- 20261017120000 et 20261018090000 restent dans le dépôt tels quels : le
-- premier a été appliqué sur le live, et cette migration passe après les
-- deux.
--
-- QUAND PLUS AUCUN BUILD NE L'APPELLE (Play Console : ni client 1.0.2+5 ni
-- build livreur issu de 79ae1f5 sur aucune piste), une migration suffira :
--   drop function if exists public.delete_my_account();
--
-- Idempotente : peut être relancée sans effet de bord.
-- ============================================================================

do $$
begin
  if to_regprocedure('public.account_deletion_execute(uuid,text)') is null then
    raise exception 'PRÉCONDITION : account_deletion_execute absente. Lancez 20261017090000_account_deletion.sql d''abord.';
  end if;
end
$$;


-- ── 1. delete_my_account() : l'entrée des anciens builds ───────────────────

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_amr     jsonb := auth.jwt() -> 'amr';
  v_auth_at double precision;
  v_app     text;
  v_result  jsonb;
  v_codes   text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  -- Ré-authentification récente, même règle que l'Edge Function : un
  -- téléphone laissé déverrouillé ne suffit pas à supprimer le compte.
  select max((e ->> 'timestamp')::double precision) into v_auth_at
    from jsonb_array_elements(case when jsonb_typeof(v_amr) = 'array' then v_amr else '[]'::jsonb end) e
   where jsonb_typeof(e -> 'timestamp') = 'number';
  if v_auth_at is null or extract(epoch from now()) - v_auth_at > 300 then
    raise exception 'reauth_required';
  end if;

  -- Ces builds ne disent pas de quelle app ils viennent : le journal prend
  -- le rôle le plus engageant du compte.
  v_app := case
             when exists (select 1 from public.drivers  where user_id = v_uid) then 'driver'
             when exists (select 1 from public.partners where user_id = v_uid) then 'partner'
             else 'client'
           end;

  v_result := public.account_deletion_execute(v_uid, v_app);

  if v_result ->> 'status' = 'blocked' then
    select string_agg(e ->> 'code', ', ' order by e ->> 'code') into v_codes
      from jsonb_array_elements(v_result -> 'blockers') e;
    -- Les builds client et livreur cherchent 'active_order' dans le message
    -- (active_orders, driver_active_orders et shop_active_orders le
    -- contiennent), le livreur aussi 'negative_balance'.
    if exists (select 1 from jsonb_array_elements(v_result -> 'blockers') e
                where e ->> 'code' = 'wallet_balance' and (e ->> 'amount')::numeric < 0) then
      v_codes := v_codes || ', negative_balance';
    end if;
    -- L'erreur annule aussi la ligne 'blocked' du journal : ces builds ne
    -- comprendraient pas un refus renvoyé sans erreur.
    raise exception 'account_deletion_blocked: %', v_codes
      using detail = (v_result -> 'blockers')::text;
  end if;

  if v_result ->> 'status' = 'ok' then
    update public.account_deletions
       set error = format('delete_my_account (ancien build) : suppression GoTrue et fichiers du Stockage à faire : %s',
                          coalesce(v_result -> 'files', '[]'::jsonb))
     where id = (v_result ->> 'log_id')::uuid;
  end if;
  -- 'already_deleted' : appel rejoué, rien à faire.
end;
$fn$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ── 2. Clés étrangères RESTRICT de 20261017090000, ré-affirmées ────────────

do $$
declare
  v_spec     record;
  v_def      text;
  v_has_null boolean;
begin
  for v_spec in
    select * from (values
      ('settlements',    'settlements_user_id_fkey'),
      ('wallets',        'wallets_user_id_fkey'),
      ('drivers',        'drivers_user_id_fkey'),
      ('partners',       'partners_user_id_fkey'),
      ('order_ratings',  'order_ratings_user_id_fkey'),
      ('driver_ratings', 'driver_ratings_user_id_fkey'),
      ('reviews',        'reviews_user_id_fkey')
    ) as t(tbl, con)
  loop
    select pg_get_constraintdef(c.oid) into v_def
      from pg_constraint c
     where c.conrelid = format('public.%I', v_spec.tbl)::regclass
       and c.conname = v_spec.con;

    if v_def is distinct from 'FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT' then
      execute format('alter table public.%I drop constraint if exists %I', v_spec.tbl, v_spec.con);
      execute format(
        'alter table public.%I add constraint %I foreign key (user_id) references auth.users(id) on delete restrict',
        v_spec.tbl, v_spec.con);
      raise notice '%.user_id : recréée en ON DELETE RESTRICT (était : %)', v_spec.tbl, coalesce(v_def, 'absente');
    end if;

    -- 20261017120000 retire aussi NOT NULL. Ces lignes n'ont pas de sens
    -- sans leur utilisateur.
    if exists (select 1 from pg_attribute
                where attrelid = format('public.%I', v_spec.tbl)::regclass
                  and attname = 'user_id'
                  and not attnotnull) then
      execute format('select exists (select 1 from public.%I where user_id is null)', v_spec.tbl) into v_has_null;
      if v_has_null then
        raise exception '%.user_id contient des NULL : NOT NULL ne peut pas être remis', v_spec.tbl;
      end if;
      execute format('alter table public.%I alter column user_id set not null', v_spec.tbl);
      raise notice '%.user_id : NOT NULL remis', v_spec.tbl;
    end if;
  end loop;
end
$$;


-- ── Vérification ───────────────────────────────────────────────────────────

do $$
declare
  v_bad text;
  v_src text;
begin
  select string_agg(t.tbl, ', ') into v_bad
    from (values
      ('settlements',    'settlements_user_id_fkey'),
      ('wallets',        'wallets_user_id_fkey'),
      ('drivers',        'drivers_user_id_fkey'),
      ('partners',       'partners_user_id_fkey'),
      ('order_ratings',  'order_ratings_user_id_fkey'),
      ('driver_ratings', 'driver_ratings_user_id_fkey'),
      ('reviews',        'reviews_user_id_fkey')
    ) as t(tbl, con)
   where not exists (
           select 1 from pg_constraint c
            where c.conrelid = format('public.%I', t.tbl)::regclass
              and c.conname = t.con
              and c.contype = 'f'
              and c.confrelid = 'auth.users'::regclass
              and c.confdeltype = 'r'
              and c.convalidated)
      or exists (
           select 1 from pg_attribute a
            where a.attrelid = format('public.%I', t.tbl)::regclass
              and a.attname = 'user_id'
              and not a.attnotnull);
  if v_bad is not null then
    raise exception 'Clés étrangères RESTRICT absentes : %', v_bad;
  end if;

  select p.prosrc into v_src from pg_proc p where p.oid = 'public.delete_my_account()'::regprocedure;
  if position('account_deletion_execute' in v_src) = 0
     or v_src ~* 'delete\s+from\s+auth\.users' then
    raise exception 'delete_my_account() ne passe pas par account_deletion_execute()';
  end if;
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then
    raise exception 'delete_my_account() : droits inattendus';
  end if;
end
$$;
