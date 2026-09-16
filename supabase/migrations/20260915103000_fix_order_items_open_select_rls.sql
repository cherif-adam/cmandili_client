-- ============================================================================
-- CMANDILI -- Close wide-open order_items SELECT policy
--
-- order_items had THREE permissive SELECT policies stacked (Postgres ORs all
-- permissive policies for the same command together). Two are correctly
-- scoped: "Users can view own order items" (customer's own order) and
-- "Partners can view order items" (that restaurant's/supermarket's own
-- orders). The third, "order_items_select", was `USING (true)` for role
-- {public} -- which includes anon, i.e. unauthenticated requests -- and
-- alone made the entire OR'd policy set equivalent to fully open: any caller
-- with just the anon key could read every order's line items (food item
-- names + quantities) for every customer on the platform, regardless of the
-- other two policies' scoping. Found during the 2026-09-14/15
-- payment/wallet + Reorder-feature review.
--
-- Fix: drop the wide-open policy. The two properly-scoped policies above are
-- untouched. Add ONE more scoped policy for the driver app -- the one real
-- consumer that had come to depend on the wide-open one:
-- driver_orders_provider.dart (cmandili_driver) queries order_items directly
-- to build the "3x Pizza Margherita" summary shown on available/active
-- orders, both for orders already assigned to that driver and for
-- unassigned ones still open for any driver to accept.
--
-- This new policy is intentionally a bit TIGHTER than the equivalent
-- `orders_driver_select` policy already live on the `orders` table itself
-- (which ORs in "status IN ('pending','ready')" unconditionally, so today
-- any authenticated user -- not just drivers -- can already read basic
-- fields of any open order via `orders`). Rather than copy that same gap
-- into order_items, the pending/ready branch here is additionally gated on
-- the caller actually having a `drivers` row. Changes nothing for real
-- drivers; closes off "any logged-in customer can read a stranger's pending
-- order's item list" for this table. `orders`' own looser policy is a
-- separate, pre-existing condition, left as-is -- out of scope for this fix,
-- noted here for visibility.
--
-- PG15-safe + idempotent (DO $$ pg_policies guard, IF EXISTS on the drop).
-- ============================================================================

DROP POLICY IF EXISTS "order_items_select" ON public.order_items;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'order_items' AND policyname = 'order_items_select_driver'
  ) THEN
    CREATE POLICY "order_items_select_driver" ON public.order_items
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.orders o
          JOIN public.drivers d ON d.user_id = auth.uid()
          WHERE o.id = order_items.order_id
            AND (d.id = o.driver_id OR o.status IN ('pending', 'ready'))
        )
      );
  END IF;
END $$;
