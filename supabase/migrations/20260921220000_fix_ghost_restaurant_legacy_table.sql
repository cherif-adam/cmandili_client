-- ============================================================================
-- CMANDILI — Fix ghost-restaurant trigger after restaurants/restaurants_legacy split
--
-- An uncommitted schema change (applied directly to remote on/around
-- 2026-09-19, alongside the multi-category "vendors" work — no local
-- migration file exists for it) renamed the original `restaurants` table to
-- `restaurants_legacy` and replaced `restaurants` with a client-facing view
-- that excludes the admin-only columns (is_blocked, commission_paid,
-- is_ghost_restaurant). `orders.restaurant_id` still points at
-- restaurants_legacy — that's where the real rows live.
--
-- auto_confirm_ghost_restaurant_order() (20260625, last replaced in
-- 20260626_ghost_restaurant_fix.sql) was never updated for the split. It
-- still runs `SELECT is_ghost_restaurant FROM public.restaurants` on every
-- INSERT into orders with a non-null restaurant_id — which now fails with
-- 42703 (column does not exist) and aborts the insert, blocking ALL
-- restaurant food orders (not just ghost-restaurant ones). This is the cause
-- of the "Error: PostgrestException ... is_ghost_restaurant does not exist"
-- seen on checkout in the client app.
--
-- Fix: read is_ghost_restaurant from public.restaurants_legacy instead —
-- the actual FK target and the table that still has the column. No other
-- behavior change from 20260626_ghost_restaurant_fix.sql.
--
-- Idempotent — safe to re-run.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_confirm_ghost_restaurant_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_ghost    BOOLEAN := FALSE;
  v_first_driver UUID;
BEGIN
  -- Only act on food orders that target a restaurant.
  IF NEW.restaurant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT is_ghost_restaurant INTO v_is_ghost
  FROM public.restaurants_legacy
  WHERE id = NEW.restaurant_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- Skip straight to 'ready' — matches the courier/facture pattern and makes
  -- the order immediately visible in the driver app's availableOrdersProvider.
  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  -- Targeted waterfall dispatch (mirrors notify_fcm_fanout_ready_order()).
  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_restaurant_order()
  TO service_role;
