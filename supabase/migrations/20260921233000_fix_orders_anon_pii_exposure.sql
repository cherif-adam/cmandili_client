-- ============================================================================
-- CMANDILI -- Close anon-readable customer PII on orders / orders_with_customer
--
-- Found 2026-09-21 by auditing what the *publishable* anon key can read. That
-- key ships inside every released APK, so "anon" is effectively the public
-- internet. Two independent holes, each sufficient on its own:
--
--   LEAK A -- public.orders_with_customer (136 of 136 rows to anon).
--     The view is owned by `postgres` and was created WITHOUT
--     (security_invoker = true). A Postgres view runs with its OWNER's rights
--     unless that option is set, so it bypasses RLS on the tables underneath
--     it entirely. The view LEFT JOINs profiles and exposes customer_name +
--     customer_phone, so this handed out every customer's name and phone
--     number for every order on the platform, to anyone with the anon key --
--     and, worse, to any logged-in user too, since the bypass is not specific
--     to anon. `profiles` itself is correctly locked to own-row-only; the view
--     was laundering it.
--
--   LEAK B -- public.orders (90 of 136 rows to anon).
--     `orders` carries NINE permissive SELECT policies, and Postgres ORs all
--     permissive policies together, so the most permissive one wins outright.
--     Three of them contain a branch with no auth.uid() binding at all, and
--     none of the nine is restricted `TO authenticated`, so they apply to
--     PUBLIC (which includes anon):
--       - "Drivers can view available/assigned orders" -> `driver_id IS NULL`
--         This is the one that actually produced the 90 rows: the leaked set
--         is exactly "every order with no driver assigned yet", cancelled
--         ones included.
--       - "orders_driver_select"            -> `status IN ('pending','ready')`
--       - "drivers_see_offers_and_unassigned"
--                 -> `status IN ('pending','ready') AND assigned_driver_id IS NULL`
--
-- This is the follow-up that 20260915103000_fix_order_items_open_select_rls.sql
-- explicitly deferred: that migration tightened the equivalent driver branch on
-- order_items and noted that `orders`' own looser policy was "a separate,
-- pre-existing condition, left as-is -- out of scope for this fix, noted here
-- for visibility". This is that fix.
--
-- WHAT THIS CHANGES FOR REAL USERS -- read before applying:
--   Flipping the view to security_invoker means its LEFT JOIN on `profiles` is
--   now RLS-filtered like everything else, so p.full_name / p.phone resolve to
--   NULL for anyone who is not that customer. The view's customer_name /
--   customer_phone are COALESCE chains that fall back to
--   delivery_address->>'recipientName' / ->>'phone', then recipient_name /
--   recipient_phone -- all of which live on the order row itself and stay
--   readable. Measured against live data at the time of writing: 110/136 orders
--   keep a resolvable customer_name and 113/136 keep a customer_phone. The
--   ~23 that lose the phone are synthetic test inserts and `facture`
--   (bill-payment) orders, which have no delivery address and no restaurant
--   partner attached anyway. Real app-created food orders always carry
--   recipientName + phone in delivery_address (written by
--   DeliveryAddress.toJson() at checkout), so the partner-facing "call the
--   customer" flow is unaffected. If a profile-based fallback is ever needed
--   for partners, that wants its own narrowly-scoped profiles SELECT policy --
--   deliberately NOT bundled here.
--
-- Scope kept deliberately surgical, mirroring the order_items precedent: only
-- the three leaking policies are dropped, replaced by ONE correctly-bound
-- driver policy. The other six SELECT policies are all properly identity-bound
-- already (auth.uid() = user_id, or a partners-entity match) and are left
-- untouched -- for anon they simply match zero rows, since auth.uid() is NULL.
-- They ARE redundant duplicates of each other (three near-identical customer
-- policies, three near-identical partner ones) and consolidating them is worth
-- doing, but that is cleanup, not a security fix, and is left for a separate
-- change so this one stays easy to review and revert.
--
-- Idempotent -- safe to re-run.
-- ============================================================================


-- ── 1. LEAK A: make the view respect the caller's RLS ────────────────────────
-- ALTER (not CREATE OR REPLACE) so the column list and definition are preserved
-- byte-for-byte; only the security context changes.

ALTER VIEW public.orders_with_customer SET (security_invoker = true);


-- ── 2. LEAK B: drop the three policies with identity-free branches ───────────

DROP POLICY IF EXISTS "Drivers can view available/assigned orders" ON public.orders;
DROP POLICY IF EXISTS "orders_driver_select"                       ON public.orders;
DROP POLICY IF EXISTS "drivers_see_offers_and_unassigned"          ON public.orders;


-- ── 3. Replace them with one correctly-bound driver policy ───────────────────
-- Preserves every legitimate driver read:
--   a. orders currently assigned to me            (driver_id)
--   b. offers currently pointed at me             (assigned_driver_id)
--   c. the open dispatch pool of unassigned work  (status pending/ready)
-- The whole thing is gated on the caller actually having a `drivers` row, so
-- branch (c) is no longer an open door for anon or for any logged-in customer
-- -- the same tightening already applied to order_items in 20260915103000.
-- `TO authenticated` additionally keeps anon out at the role level, before any
-- predicate is even evaluated.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'orders'
      AND policyname = 'orders_select_driver_scoped'
  ) THEN
    CREATE POLICY "orders_select_driver_scoped"
      ON public.orders FOR SELECT
      TO authenticated
      USING (
        EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = auth.uid())
        AND (
             driver_id          IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
          OR assigned_driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
          OR (status IN ('pending', 'ready') AND driver_id IS NULL)
        )
      );
  END IF;
END $$;


-- ── 4. Defense in depth: take anon off both objects entirely ─────────────────
-- Supabase's default setup grants anon the full DML set on every table and
-- leans on RLS alone to gate it. No anon flow in any of the three apps reads or
-- writes orders -- placing an order requires an authenticated session
-- (OrderRepository.createOrder throws 'User not authenticated' without one) --
-- so the grant buys nothing and costs a second chance for a policy mistake to
-- become a breach. Revoking is belt-and-braces alongside step 3, not a
-- substitute for it.

REVOKE ALL ON public.orders                FROM anon;
REVOKE ALL ON public.orders_with_customer  FROM anon;
