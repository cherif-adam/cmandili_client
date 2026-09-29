-- One push token per user PER APP, and a registration that cannot fail
-- ============================================================================
-- 20260916210000_dedupe_device_tokens added UNIQUE (user_id, platform) and
-- said the apps would switch their upsert to that conflict target. They never
-- did: all three still upsert ON CONFLICT (token). So whenever a phone gets a
-- new FCM token (reinstall, fresh build, Firebase rotation) the insert hits
-- the (user_id, platform) constraint, fails with 23505, and the server keeps
-- pushing to the old, dead token -- the notification simply never arrives.
--
-- (user_id, platform) was also the wrong key: the client, driver and partner
-- apps each have their own token on the same phone, so a user signed in to
-- two of them could only ever have one registered, and a customer push could
-- land in the partner app.
--
-- Fix:
--   * device_tokens.app ('client' | 'driver' | 'partner'; 'unknown' for rows
--     registered before this change) and UNIQUE (user_id, platform, app).
--   * register_device_token(): deletes any row holding this token (another
--     account that used the same phone) and this user's previous token for
--     this app, then inserts. SECURITY DEFINER because the first delete can
--     touch another user's row, which RLS on the table rightly forbids.
-- push-on-order-status then sends each app's pushes to that app's tokens.

begin;

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

commit;
