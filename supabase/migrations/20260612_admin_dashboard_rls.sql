-- ============================================================================
-- Migration: Admin Dashboard RLS Policies
-- Purpose: Allow the admin dashboard (using service_role key) to read all data
--          and allow wallet upserts for blocking/unblocking accounts.
--
-- The admin dashboard uses the service_role key (server-side), which bypasses
-- all RLS by default. No additional policies are needed for reads.
--
-- However, the block/unblock action fires from the browser (client-side) using
-- the anon key + an admin user session. We need a policy for that.
-- ============================================================================

-- 1. Allow authenticated users to upsert wallets (for admin block/unblock)
--    In production, restrict this to users with role='admin' in profiles.
DROP POLICY IF EXISTS "wallets_upsert_own" ON public.wallets;
CREATE POLICY "wallets_upsert_own" ON public.wallets
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Optional: Add admin role column to profiles if you want role-based access
-- ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
-- UPDATE public.profiles SET role = 'admin' WHERE id = '<your-admin-user-id>';

-- 2. Ensure the orders_with_customer view is accessible
GRANT SELECT ON public.orders_with_customer TO anon, authenticated;

-- 3. Give the service role full access to all tables used by the dashboard
-- (service_role bypasses RLS but needs GRANT for explicit table access)
GRANT SELECT ON public.drivers TO service_role;
GRANT SELECT ON public.restaurants TO service_role;
GRANT SELECT ON public.partners TO service_role;
GRANT SELECT ON public.profiles TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.wallets TO service_role;
GRANT SELECT ON public.settlements TO service_role;
GRANT SELECT ON public.orders TO service_role;
GRANT SELECT ON public.orders_with_customer TO service_role;
GRANT SELECT ON public.global_settings TO service_role;
