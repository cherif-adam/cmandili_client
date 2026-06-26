-- ============================================================================
-- CMANDILI — Ghost Restaurant feature
--
-- A "ghost restaurant" has no partner app. Admin manages its menu directly
-- and orders are auto-confirmed + dispatched to a driver immediately, without
-- any partner confirmation step.
--
-- Changes:
--   1. Add is_ghost_restaurant flag to restaurants table.
--   2. DB trigger: when an order is inserted for a ghost restaurant, immediately
--      UPDATE its status to 'confirmed'. This fires the existing UPDATE trigger
--      (on_order_status_push → notify_fcm_on_order_status), which calls the
--      edge function, which calls dispatch_driver_for_order. No new dispatch
--      logic needed — we reuse the entire existing waterfall.
--
-- The INSERT trigger (on_order_insert_push → notify_fcm_on_new_order) still
-- fires first with status='pending'. Since ghost restaurants have no entry in
-- the partners table, partnerUserId resolves to NULL in the edge function, so
-- no alarm is sent to a non-existent partner. The customer receives 'pending'
-- followed immediately by 'confirmed' — standard UX for auto-confirmed orders.
--
-- Idempotent — safe to re-run.
-- ============================================================================


-- ── 1. Column ────────────────────────────────────────────────────────────────

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS is_ghost_restaurant BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.restaurants.is_ghost_restaurant IS
  'True = admin-managed ghost restaurant: orders are auto-confirmed and dispatched without partner involvement.';


-- ── 2. Auto-confirm trigger function ─────────────────────────────────────────
-- Fires AFTER INSERT on orders. If the order belongs to a ghost restaurant,
-- immediately flips the status to confirmed. The existing on_order_status_push
-- trigger then fires on the UPDATE and kicks off driver dispatch.

CREATE OR REPLACE FUNCTION public.auto_confirm_ghost_restaurant_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_ghost BOOLEAN := FALSE;
BEGIN
  -- Only act on food orders that target a restaurant.
  IF NEW.restaurant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT is_ghost_restaurant INTO v_is_ghost
  FROM public.restaurants
  WHERE id = NEW.restaurant_id;

  IF v_is_ghost = TRUE THEN
    UPDATE public.orders
    SET status = 'confirmed'
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_restaurant_order()
  TO service_role;


-- ── 3. Attach trigger ────────────────────────────────────────────────────────
-- Named "after_insert_ghost_confirm" so it sorts after "on_order_insert_push"
-- alphabetically (a < o), meaning the partner-alarm edge call fires first,
-- then our auto-confirm runs. In practice both HTTP posts are async (pg_net)
-- so ordering doesn't matter functionally.

DROP TRIGGER IF EXISTS after_insert_ghost_confirm ON public.orders;
CREATE TRIGGER after_insert_ghost_confirm
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_ghost_restaurant_order();
