-- ============================================================================
-- Migration: Add is_admin flag to profiles
-- Purpose: Gate access to the admin dashboard. Only profiles with
--          is_admin = TRUE are allowed to sign in to the Next.js admin panel.
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- Allow the authenticated user to read their own is_admin flag.
-- The dashboard login check uses the anon key + user session, so the user
-- must be able to SELECT their own profile row.
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
