-- ============================================================================
-- CMANDILI — Ghost Restaurant fix: 'confirmed' → 'ready' + inline dispatch
--
-- Root-cause analysis of the dispatch bug:
--
--   The original trigger (20260625_ghost_restaurant.sql) set status='confirmed'.
--   Two problems with that:
--
--   1. The driver app's availableOrdersProvider only shows orders where
--      status='ready' AND driver_id IS NULL. An order stuck at 'confirmed'
--      is permanently invisible to every driver — there is no broadcast
--      fallback because there is no partner to push the order onward to
--      'preparing' / 'ready'.
--
--   2. CMANDILI_CONTEXT already states the rule:
--        "no partner → create with status='ready'"
--      Ghost restaurants are a direct-to-driver type; 'confirmed' is
--      wrong for them.
--
-- Fix:
--   Replace auto_confirm_ghost_restaurant_order() so it:
--     a. Sets status = 'ready' (matches the courier/facture pattern and
--        makes the order immediately visible in the driver-app broadcast list).
--     b. Additionally calls next_eligible_driver() + offer_order_to_driver()
--        from inside the trigger, the same pattern used by
--        notify_fcm_fanout_ready_order() in 20260510_assignment_and_distance.sql.
--        This sends a targeted FCM offer to the nearest available driver.
--     c. If no driver is online right now, the order stays at 'ready' and
--        any driver who comes online can see and accept it — no dead end.
--
-- The on_order_status_push UPDATE trigger still fires (pending → ready
-- status change), so the customer gets the correct 'ready' notification.
-- The partner notification is still skipped because ghost restaurants have
-- no row in the partners table (partnerUserId = null in the edge function).
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
  FROM public.restaurants
  WHERE id = NEW.restaurant_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- ── a. Skip straight to 'ready' ─────────────────────────────────────────
  -- 'ready' makes the order visible in the driver app's availableOrdersProvider
  -- (which filters status='ready' AND driver_id IS NULL). This is the same
  -- approach used by courier and facture orders (direct-to-driver types).
  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  -- ── b. Targeted waterfall dispatch ──────────────────────────────────────
  -- Mirror the logic from notify_fcm_fanout_ready_order() (20260510).
  -- Offer the order to the nearest eligible online driver. If accepted,
  -- the waterfall rotates to the next driver on timeout (cron + pass_order_offer).
  -- If no driver is found, the order stays at 'ready' and any driver who
  -- comes online can see and accept it via the broadcast fallback — no dead end.
  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_restaurant_order()
  TO service_role;
