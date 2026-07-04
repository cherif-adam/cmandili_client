-- ============================================================================
-- CMANDILI — Tighten the orders UPDATE RLS policies (P1 security fix)
--
-- Problem (AUDIT_REPORT.md): the live DB carried TWO permissive UPDATE
-- policies on public.orders that allowed ANY authenticated user to update
-- ANY order row:
--
--   • "orders_update"                          USING (auth.role() = 'authenticated')
--   • "Authenticated users can update orders"  USING (auth.role() = 'authenticated')  (legacy)
--
-- Any logged-in customer could therefore modify someone else's order
-- (status, amounts, driver assignment). Both are dropped here and replaced
-- with role-scoped policies mapped from every legitimate client update path:
--
--   customer  → own orders only            (user_id = auth.uid())
--               [cancel flow, payment-failure cancel, courier/facture
--                "confirm receipt" → delivered]
--   partner   → orders of their own venue  (partners.entity_id → orders.restaurant_id
--                                           / orders.supermarket_id)
--               [accept/reject, preparing/ready, self-delivery, mark delivered]
--   driver    → a) orders they already accepted (driver_id = their drivers.id)
--                  [pickedUp/onTheWay/delivered, receipt photo upload]
--               b) claiming an unaccepted order (driver_id IS NULL) that is
--                  either offered to them (assigned_driver_id = theirs) or in
--                  the unassigned broadcast pool (status pending/ready) —
--                  the claim itself writes driver_id = their id, which is
--                  what WITH CHECK enforces.
--   admin     → any order when profiles.is_admin = TRUE
--
-- Paths that do NOT need policies (bypass RLS entirely):
--   • All dispatch-waterfall functions (next_eligible_driver,
--     offer_order_to_driver, rotate_expired_offers, pass_order_offer,
--     dispatch_driver_for_order, admin_dispatch_order), the ghost
--     auto-confirm triggers, and generate_settlements_on_delivery are
--     SECURITY DEFINER owned by postgres (table owner, FORCE RLS off).
--   • The admin dashboard reads/writes via the service_role key.
--   • Edge functions use the service_role client.
--
-- INSERT / SELECT / DELETE policies are deliberately untouched — in
-- particular orders_insert_not_blocked (blocked-customer enforcement).
--
-- PG15-safe: no CREATE POLICY IF NOT EXISTS; every CREATE POLICY is guarded
-- by a DO $$ block checking pg_policies. Idempotent — safe to re-run.
-- ============================================================================


-- ── 1. Drop the two overly-broad UPDATE policies ─────────────────────────────

DROP POLICY IF EXISTS "orders_update" ON public.orders;
DROP POLICY IF EXISTS "Authenticated users can update orders" ON public.orders;


-- ── 2. Customer: update own orders only ──────────────────────────────────────
-- Covers: customer cancellation (status/cancellation_reason/cancelled_by),
-- payment-failure cancel, and the courier/facture "confirm receipt" flow.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'orders'
      AND policyname = 'orders_customer_update'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_customer_update"
        ON public.orders FOR UPDATE
        TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid())
    $p$;
  END IF;
END $$;


-- ── 3. Partner: update orders belonging to their venue ───────────────────────
-- Same entity chain as the deployed orders_partner_select policy.
-- entity_id::text::uuid works whether partners.entity_id is TEXT (base
-- schema file) or UUID (live DB); the regex guard skips malformed ids.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'orders'
      AND policyname = 'orders_partner_update'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_partner_update"
        ON public.orders FOR UPDATE
        TO authenticated
        USING (
          restaurant_id IN (
            SELECT entity_id::text::uuid FROM public.partners
            WHERE user_id = auth.uid()
              AND partner_type = 'restaurant'
              AND entity_id::text ~ '^[0-9a-f-]{36}$'
          )
          OR supermarket_id IN (
            SELECT entity_id::text::uuid FROM public.partners
            WHERE user_id = auth.uid()
              AND partner_type = 'supermarket'
              AND entity_id::text ~ '^[0-9a-f-]{36}$'
          )
        )
        WITH CHECK (
          restaurant_id IN (
            SELECT entity_id::text::uuid FROM public.partners
            WHERE user_id = auth.uid()
              AND partner_type = 'restaurant'
              AND entity_id::text ~ '^[0-9a-f-]{36}$'
          )
          OR supermarket_id IN (
            SELECT entity_id::text::uuid FROM public.partners
            WHERE user_id = auth.uid()
              AND partner_type = 'supermarket'
              AND entity_id::text ~ '^[0-9a-f-]{36}$'
          )
        )
    $p$;
  END IF;
END $$;


-- ── 4a. Driver: update orders they already accepted ──────────────────────────
-- Same name/definition as the (unpushed) 20260623 facture migration so both
-- guards recognise each other. Covers status transitions + receipt upload.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'orders'
      AND policyname = 'orders_driver_update_own'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_driver_update_own"
        ON public.orders FOR UPDATE
        TO authenticated
        USING (
          driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
        )
        WITH CHECK (
          driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
        )
    $p$;
  END IF;
END $$;


-- ── 4b. Driver: claim an unaccepted order ────────────────────────────────────
-- The accept flow does UPDATE orders SET driver_id = <self> WHERE id = ?
-- AND driver_id IS NULL (atomic claim). At that instant driver_id is NULL,
-- so 4a cannot authorise it. Claimable rows are:
--   • currently offered to this driver via the waterfall
--     (assigned_driver_id = theirs — any status; 20260605 dispatches on
--     'confirmed' too), or
--   • in the unassigned broadcast pool (status pending/ready) — mirrors the
--     drivers_see_offers_and_unassigned SELECT policy.
-- The caller must actually BE a driver: without the EXISTS guard the pool
-- branch is identity-free, and because permissive WITH CHECKs are OR'd
-- across policies, a plain customer passing USING here could re-scope an
-- unassigned order (e.g. set user_id = their own uid) and hijack it.
-- WITH CHECK pins the post-image to driver_id = their own drivers.id, so a
-- driver cannot claim on behalf of someone else or null-out an assignment.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'orders'
      AND policyname = 'orders_driver_claim'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_driver_claim"
        ON public.orders FOR UPDATE
        TO authenticated
        USING (
          driver_id IS NULL
          AND EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid())
          AND (
            assigned_driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
            OR (assigned_driver_id IS NULL AND status IN ('pending', 'ready'))
          )
        )
        WITH CHECK (
          driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
        )
    $p$;
  END IF;
END $$;


-- ── 5. Admin: profiles.is_admin = TRUE may update any order ──────────────────
-- The Next.js dashboard currently writes via service_role (RLS-bypassing);
-- this policy covers any client-side admin action using the anon key + an
-- admin session (same model as the dashboard login gate).

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'orders'
      AND policyname = 'orders_admin_update'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "orders_admin_update"
        ON public.orders FOR UPDATE
        TO authenticated
        USING (
          EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND is_admin = TRUE
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND is_admin = TRUE
          )
        )
    $p$;
  END IF;
END $$;
