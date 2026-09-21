-- ============================================================================
-- CMANDILI — Fix ghost-supermarket trigger after supermarkets/supermarkets_legacy split
--
-- Same drift as 20260921220000_fix_ghost_restaurant_legacy_table.sql: the
-- uncommitted schema change that split restaurants also split supermarkets
-- into supermarkets_legacy (the real data, still orders.supermarket_id's FK
-- target, still has is_ghost_restaurant) and a slimmer `supermarkets` view
-- that drops it.
--
-- auto_confirm_ghost_supermarket_order() (20260626_ghost_supermarket.sql)
-- still reads is_ghost_restaurant from public.supermarkets, so it throws
-- 42703 on every INSERT into orders with a non-null supermarket_id. Because
-- every supermarket defaults is_ghost_restaurant = TRUE (supermarkets have
-- no partner app), this breaks EVERY supermarket/grocery order, not just a
-- subset — same failure mode as the restaurant bug, different table.
--
-- Fix: read is_ghost_restaurant from public.supermarkets_legacy instead.
-- No other behavior change from 20260626_ghost_supermarket.sql.
--
-- Idempotent — safe to re-run.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_confirm_ghost_supermarket_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_ghost     BOOLEAN := FALSE;
  v_first_driver UUID;
BEGIN
  -- Only act on grocery orders that target a supermarket.
  IF NEW.supermarket_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT is_ghost_restaurant INTO v_is_ghost
  FROM public.supermarkets_legacy
  WHERE id = NEW.supermarket_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- Skip straight to 'ready' — makes the order visible in the driver app's
  -- availableOrdersProvider (status='ready' AND driver_id IS NULL).
  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  -- Targeted waterfall dispatch (mirrors the ghost-restaurant path).
  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_supermarket_order()
  TO service_role;
