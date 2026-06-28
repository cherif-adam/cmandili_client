-- ============================================================================
-- Migration: Add is_blocked to profiles (customer accounts)
-- Purpose: Allow admin dashboard to block/unblock customer accounts.
--          Blocked customers cannot place new orders (enforced by RLS).
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT FALSE;

-- Allow service_role (admin dashboard API) to update is_blocked on profiles
GRANT UPDATE (is_blocked) ON public.profiles TO service_role;

-- ── RLS: blocked customers cannot INSERT new orders ──────────────────────────
-- The mobile app uses the authenticated client (subject to RLS).
-- service_role bypasses RLS so the admin panel is unaffected.
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'orders'
      AND policyname = 'orders_insert_not_blocked'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_insert_not_blocked"
      ON public.orders FOR INSERT
      TO authenticated
      WITH CHECK (
        NOT EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid()
            AND is_blocked = TRUE
        )
      )
    $p$;
  END IF;
END $$;

-- Keep the existing SELECT policy (if any) working — add a permissive SELECT
-- so customers can still read their own orders after blocking enforcement.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'orders'
      AND policyname = 'orders_select_own'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_select_own"
      ON public.orders FOR SELECT
      TO authenticated
      USING (user_id = auth.uid())
    $p$;
  END IF;
END $$;
