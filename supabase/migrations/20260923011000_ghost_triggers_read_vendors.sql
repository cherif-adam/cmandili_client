-- ============================================================================
-- CMANDILI -- Ghost auto-dispatch triggers read `vendors`, not the legacy tables
--
-- Second blocker for the generic categories, sitting right behind the FK one
-- fixed in 20260923010000.
--
-- auto_confirm_ghost_restaurant_order() looks up is_ghost_restaurant in
-- restaurants_legacy (set that way earlier tonight, in
-- 20260921220000, when that WAS where the column lived and the `restaurants`
-- view had lost it). But restaurants_legacy holds only the 11 food
-- restaurants. For a florist, pet shop, bakery, gift shop or electronics
-- vendor the lookup finds NO ROW, so v_is_ghost stays NULL/FALSE, nothing
-- promotes the order past 'pending', and -- with no partner account to
-- confirm it manually -- it sits there forever. The order would be created
-- (post-FK-fix) and then silently never dispatch.
--
-- `vendors` now carries is_ghost_restaurant for every category and is the
-- established source of truth (20260922010000), so both triggers should read
-- it. This also collapses the restaurant/supermarket split in these two
-- functions: one table answers for every vendor type.
--
-- Note the supermarket trigger keys off NEW.supermarket_id and the restaurant
-- one off NEW.restaurant_id. Generic-category orders ride restaurant_id (see
-- checkout_screen.dart:226), so the restaurant trigger is the one that will
-- fire for them -- which is why it must resolve non-food vendors.
--
-- Behaviour for existing food/grocery orders is unchanged: vendors and the
-- legacy tables hold identical is_ghost_restaurant values, kept in lockstep by
-- the sync_vendor_to_legacy trigger from 20260922010000.
--
-- Idempotent -- safe to re-run.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_confirm_ghost_restaurant_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_ghost     BOOLEAN := FALSE;
  v_first_driver UUID;
BEGIN
  IF NEW.restaurant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT is_ghost_restaurant INTO v_is_ghost
  FROM public.vendors
  WHERE id = NEW.restaurant_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_restaurant_order()
  TO service_role;


CREATE OR REPLACE FUNCTION public.auto_confirm_ghost_supermarket_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_ghost     BOOLEAN := FALSE;
  v_first_driver UUID;
BEGIN
  IF NEW.supermarket_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT is_ghost_restaurant INTO v_is_ghost
  FROM public.vendors
  WHERE id = NEW.supermarket_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_supermarket_order()
  TO service_role;
