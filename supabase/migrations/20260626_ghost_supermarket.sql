-- ============================================================================
-- CMANDILI — Ghost Supermarket feature
--
-- Mirrors the ghost-restaurant feature (20260625 / 20260626) for supermarkets.
--
-- A "ghost supermarket" has no partner app. Admin manages its grocery menu
-- directly and orders are auto-set to 'ready' and dispatched to the nearest
-- driver immediately, without any partner confirmation step. The driver goes
-- to the supermarket, buys the items, and delivers them to the customer.
--
-- Supermarkets have NO row in the partners table (there is no supermarket
-- partner app), so a non-ghost supermarket order would otherwise sit at
-- 'pending' forever with nothing to confirm it. We therefore default the flag
-- to TRUE: every supermarket behaves as direct-to-driver unless an admin
-- explicitly turns the flag off.
--
-- Reuses the exact same dispatch path as ghost restaurants:
--   set status='ready' → next_eligible_driver() + offer_order_to_driver()
-- (next_eligible_driver already LEFT JOINs supermarkets for pickup coords —
-- see 20260510_assignment_and_distance.sql, no change needed there.)
--
-- Idempotent — safe to re-run.
-- ============================================================================


-- ── 1. Column ────────────────────────────────────────────────────────────────

ALTER TABLE public.supermarkets
  ADD COLUMN IF NOT EXISTS is_ghost_restaurant BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN public.supermarkets.is_ghost_restaurant IS
  'True = admin-managed ghost supermarket: orders are auto-set to ready and dispatched to a driver without partner involvement. Defaults TRUE because supermarkets have no partner app.';


-- ── 2. Auto-dispatch trigger function ────────────────────────────────────────
-- Fires AFTER INSERT on orders. If the order belongs to a ghost supermarket,
-- flips status to 'ready' (so it shows in the driver app's availableOrders list)
-- and offers it to the nearest online driver via the existing waterfall.

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
  FROM public.supermarkets
  WHERE id = NEW.supermarket_id;

  IF v_is_ghost IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- ── a. Skip straight to 'ready' ─────────────────────────────────────────
  -- 'ready' makes the order visible in the driver app's availableOrdersProvider
  -- (status='ready' AND driver_id IS NULL), same as courier / facture / ghost
  -- restaurant direct-to-driver types.
  UPDATE public.orders
  SET status = 'ready'
  WHERE id = NEW.id;

  -- ── b. Targeted waterfall dispatch ──────────────────────────────────────
  -- Offer the order to the nearest eligible online driver. If none is online,
  -- the order stays at 'ready' and any driver who comes online can see and
  -- accept it via the broadcast fallback — no dead end.
  v_first_driver := public.next_eligible_driver(NEW.id);
  IF v_first_driver IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_confirm_ghost_supermarket_order()
  TO service_role;


-- ── 3. Attach trigger ────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS after_insert_ghost_supermarket_confirm ON public.orders;
CREATE TRIGGER after_insert_ghost_supermarket_confirm
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_ghost_supermarket_order();
