-- ============================================================================
-- Test (toujours annulé) de 20260929100000_device_tokens_per_app.sql, à lancer
-- sur le live avec :
--   supabase db query --linked --file supabase/tests/device_tokens_per_app_test.sql
-- Tout tient dans UN bloc DO qui finit TOUJOURS par RAISE EXCEPTION : rien
-- n'est gardé. Résultat dans le message : DRYRUN_OK :: … ou DRYRUN_FAIL :: …
--
-- Scénarios (comptes de test créés dans le bloc, adresses @test.invalid) :
--   T0 les lignes déjà sur le live passent en app = 'unknown', aucune perdue ;
--   T1 un même compte ouvre client, livreur et partenaire sur un téléphone :
--      3 lignes, une par application ;
--   T2 chaque push ne va qu'à l'application visée (même requête que
--      push-on-order-status, tokensForUser) ;
--   T3 un nouveau jeton dans une application ne remplace que la sienne ;
--   T4 la déconnexion d'une application (signOut : delete par jeton, sous
--      RLS) n'efface que son jeton ;
--   T5 un autre compte se connecte à la même application du même téléphone :
--      le jeton passe à ce compte ;
--   T6 une ancienne version installée (upsert sur le jeton, sans app) est
--      toujours acceptée et reçoit toujours les push ;
--   T7 la suppression du compte (account_deletion_execute) efface tous ses
--      jetons, toutes applications.
-- ============================================================================
do $test$
declare
  u_a      uuid := gen_random_uuid();  -- le testeur : même compte, 3 applications, 1 téléphone
  u_b      uuid := gen_random_uuid();  -- un autre compte qui se connecte ensuite sur ce téléphone
  u_o      uuid := gen_random_uuid();  -- un compte sur une ancienne version de l'application
  v_before integer;
  v_n      integer;
  v_got    text;
  v_res    jsonb;
  v_ok     text := '';
  v_fail   text := '';
begin
  select count(*) into v_before from public.device_tokens;

  -- ── Migration 20260929100000, telle quelle (sans son begin/commit) ─────────
  alter table public.device_tokens
    add column if not exists app text not null default 'unknown';

  alter table public.device_tokens
    drop constraint if exists device_tokens_user_platform_unique;

  alter table public.device_tokens
    drop constraint if exists device_tokens_user_platform_app_unique;
  alter table public.device_tokens
    add constraint device_tokens_user_platform_app_unique
    unique (user_id, platform, app);

  create or replace function public.register_device_token(
    p_token    text,
    p_platform text,
    p_app      text
  )
  returns void
  language plpgsql
  security definer
  set search_path = ''
  as $$
  declare
    v_user uuid := auth.uid();
  begin
    if v_user is null then
      raise exception 'not signed in';
    end if;
    if p_app not in ('client', 'driver', 'partner') then
      raise exception 'unknown app %', p_app;
    end if;
    if coalesce(p_token, '') = '' then
      return;
    end if;

    -- This physical install now belongs to this user and app only.
    delete from public.device_tokens where token = p_token;

    -- This user's previous token for this app (and the untagged legacy row,
    -- which the app it came from will re-register under its own tag).
    delete from public.device_tokens
     where user_id = v_user
       and platform = p_platform
       and app in (p_app, 'unknown');

    insert into public.device_tokens (token, user_id, platform, app, updated_at)
    values (p_token, v_user, p_platform, p_app, now());
  end;
  $$;

  revoke execute on function public.register_device_token(text, text, text) from public, anon;
  grant execute on function public.register_device_token(text, text, text) to authenticated;

  -- ── T0 : les lignes existantes ────────────────────────────────────────────
  select count(*) into v_n from public.device_tokens where app = 'unknown';
  if v_n = v_before and (select count(*) from public.device_tokens) = v_before then
    v_ok := v_ok || format('T0 %s lignes existantes en unknown | ', v_n);
  else
    v_fail := v_fail || format('T0 %s/%s en unknown | ', v_n, v_before);
  end if;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'tokens-' || u::text || '@test.invalid',
         jsonb_build_object('full_name', 'Test jetons', 'phone', '+21600000000'),
         '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
    from unnest(array[u_a, u_b, u_o]) as u;

  -- ── T1 : même compte sur les 3 applications du même téléphone ─────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.register_device_token('dryrun-a-client',  'android', 'client');
  perform public.register_device_token('dryrun-a-driver',  'android', 'driver');
  perform public.register_device_token('dryrun-a-partner', 'android', 'partner');
  reset role;
  select string_agg(app || '=' || token, ',' order by app) into v_got
    from public.device_tokens where user_id = u_a;
  if v_got = 'client=dryrun-a-client,driver=dryrun-a-driver,partner=dryrun-a-partner' then
    v_ok := v_ok || 'T1 3 lignes | ';
  else
    v_fail := v_fail || 'T1 ' || coalesce(v_got, 'aucune') || ' | ';
  end if;

  -- ── T2 : chaque push va à la bonne application ────────────────────────────
  -- Même filtre que push-on-order-status (tokensForUser) : app IN (cible, 'unknown').
  select string_agg(token, ',' order by token) into v_got
    from public.device_tokens where user_id = u_a and app in ('client', 'unknown');
  if v_got = 'dryrun-a-client' then v_ok := v_ok || 'T2 client | ';
  else v_fail := v_fail || 'T2 client ' || coalesce(v_got, 'aucun') || ' | '; end if;
  select string_agg(token, ',' order by token) into v_got
    from public.device_tokens where user_id = u_a and app in ('driver', 'unknown');
  if v_got = 'dryrun-a-driver' then v_ok := v_ok || 'T2 livreur | ';
  else v_fail := v_fail || 'T2 livreur ' || coalesce(v_got, 'aucun') || ' | '; end if;
  select string_agg(token, ',' order by token) into v_got
    from public.device_tokens where user_id = u_a and app in ('partner', 'unknown');
  if v_got = 'dryrun-a-partner' then v_ok := v_ok || 'T2 partenaire | ';
  else v_fail := v_fail || 'T2 partenaire ' || coalesce(v_got, 'aucun') || ' | '; end if;

  -- ── T3 : nouveau jeton FCM dans l'app client seulement ────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.register_device_token('dryrun-a-client-2', 'android', 'client');
  reset role;
  select string_agg(app || '=' || token, ',' order by app) into v_got
    from public.device_tokens where user_id = u_a;
  if v_got = 'client=dryrun-a-client-2,driver=dryrun-a-driver,partner=dryrun-a-partner' then
    v_ok := v_ok || 'T3 seul le client change | ';
  else
    v_fail := v_fail || 'T3 ' || coalesce(v_got, 'aucune') || ' | ';
  end if;

  -- ── T4 : déconnexion de l'app livreur (signOut : delete par jeton, RLS) ───
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  delete from public.device_tokens where token = 'dryrun-a-driver';
  get diagnostics v_n = row_count;
  reset role;
  select string_agg(app || '=' || token, ',' order by app) into v_got
    from public.device_tokens where user_id = u_a;
  if v_n = 1 and v_got = 'client=dryrun-a-client-2,partner=dryrun-a-partner' then
    v_ok := v_ok || 'T4 seul le jeton livreur part | ';
  else
    v_fail := v_fail || format('T4 %s supprimé(s), reste %s | ', v_n, coalesce(v_got, 'rien'));
  end if;

  -- ── T5 : un autre compte se connecte à l'app partenaire du même téléphone ─
  perform set_config('request.jwt.claims', json_build_object('sub', u_b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.register_device_token('dryrun-a-partner', 'android', 'partner');
  reset role;
  select string_agg(app || '=' || token, ',' order by app) into v_got
    from public.device_tokens where user_id = u_a;
  if v_got = 'client=dryrun-a-client-2'
     and (select user_id from public.device_tokens where token = 'dryrun-a-partner') = u_b then
    v_ok := v_ok || 'T5 jeton repris par le nouveau compte | ';
  else
    v_fail := v_fail || 'T5 ' || coalesce(v_got, 'rien') || ' | ';
  end if;

  -- ── T6 : ancienne version installée (upsert sur le jeton, sans app) ───────
  perform set_config('request.jwt.claims', json_build_object('sub', u_o, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.device_tokens (user_id, token, platform, updated_at)
  values (u_o, 'dryrun-o-old', 'android', now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = excluded.updated_at;
  reset role;
  select string_agg(token, ',' order by token) into v_got
    from public.device_tokens where user_id = u_o and app in ('partner', 'unknown');
  if v_got = 'dryrun-o-old'
     and (select app from public.device_tokens where token = 'dryrun-o-old') = 'unknown' then
    v_ok := v_ok || 'T6 ancienne version acceptée et jointe | ';
  else
    v_fail := v_fail || 'T6 ' || coalesce(v_got, 'rien') || ' | ';
  end if;

  -- ── T7 : suppression du compte = tous ses jetons, toutes applications ─────
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.register_device_token('dryrun-a-driver-2', 'android', 'driver');
  reset role;
  select count(*) into v_n from public.device_tokens where user_id = u_a;
  v_res := public.account_deletion_execute(u_a, 'client');
  if v_n = 2 and v_res ->> 'status' = 'ok'
     and not exists (select 1 from public.device_tokens where user_id = u_a) then
    v_ok := v_ok || 'T7 suppression : 2 jetons effacés | ';
  else
    v_fail := v_fail || format('T7 %s jetons avant, statut %s, reste %s | ', v_n, v_res ->> 'status',
                               (select count(*) from public.device_tokens where user_id = u_a));
  end if;

  -- Toujours annulé.
  if v_fail = '' then
    raise exception 'DRYRUN_OK :: %', v_ok;
  else
    raise exception 'DRYRUN_FAIL :: % ## OK : %', v_fail, v_ok;
  end if;
end
$test$;
