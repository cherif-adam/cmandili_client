-- ============================================================================
-- CMANDILI -- Close self-elevation hole on profiles.is_admin (and is_blocked)
--
-- profiles' UPDATE/INSERT RLS policies are both scoped only as
-- `auth.uid() = id` with no WITH CHECK column list. RLS is row-level only --
-- it can restrict WHICH row you touch, never WHICH column -- so once that
-- row check passes, every column is writable. Confirmed live: authenticated
-- and anon both hold blanket TABLE-level INSERT/UPDATE grants on profiles
-- (Supabase's default "grant everything, RLS gates it" setup), which covers
-- every column including is_admin.
--
-- 20260628_profiles_is_blocked.sql made the same assumption this migration
-- almost repeated: it grants UPDATE (is_blocked) to service_role specifically,
-- but that's meaningless on its own -- authenticated's blanket table-level
-- UPDATE already covers is_blocked regardless, so any blocked customer can
-- currently unblock themselves the same way a non-admin can self-promote.
-- Column-level GRANT/REVOKE entries are ADDITIONAL to table-level privilege,
-- not a restriction of it -- Postgres ORs them. REVOKE UPDATE (is_admin)
-- alone (tried first, rolled back after a failing dry-run test) does NOT
-- work while the table-level grant still stands; the table-level grant has
-- to go, replaced by an explicit column allowlist.
--
-- handle_new_user() (auto-provisions the profile row on signup) is
-- SECURITY DEFINER owned by postgres and only ever writes id/full_name/
-- avatar_url -- runs as postgres, unaffected by anything revoked here from
-- authenticated/anon. service_role is not named in the REVOKE below, so its
-- existing admin-dashboard access (supabaseAdmin, bypasses RLS) is untouched.
-- ============================================================================

REVOKE INSERT, UPDATE ON public.profiles FROM authenticated, anon;

-- Client-writable allowlist: exactly the columns the driver/partner/customer
-- apps' own profile-edit code actually sets (grep-confirmed:
-- cmandili_driver + cmandili_partner profile_repository.dart, and the
-- checkout screen's contact-info save). id is required in the INSERT list
-- only because the RLS WITH CHECK (auth.uid() = id) needs it settable to
-- satisfy that check -- the check still forces id = auth.uid() regardless.
--
-- Deliberately excluded (admin/service_role or definer-trigger only from
-- here on): is_admin, is_blocked, email, created_at. updated_at stays
-- client-writable -- there is no bump-on-update trigger on this table, so
-- the apps set it themselves on every edit; excluding it would break every
-- profile save.
GRANT INSERT (id, full_name, avatar_url, phone, updated_at)
  ON public.profiles TO authenticated, anon;

GRANT UPDATE (full_name, avatar_url, phone, updated_at)
  ON public.profiles TO authenticated, anon;
