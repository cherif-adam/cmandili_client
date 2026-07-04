-- ============================================================================
-- CMANDILI — Block orders from CLOSED venues (ghost-order fix, P0)
--
-- Problem: a customer could place a real order against a restaurant or
-- supermarket whose `is_open = false` (manually closed by the partner, or
-- auto-closed by the pg_cron job in 20260629_restaurant_operating_hours.sql).
-- The client only used `is_open` for a badge, and no RLS/trigger enforced it,
-- so "ghost" orders landed on venues that would never accept them.
--
-- Fix: a BEFORE INSERT trigger on `orders` that rejects an insert when the
-- targeted venue is closed. The DB is the source of truth — this holds even if
-- the client UI check is bypassed or goes stale.
--
--   • Food orders        → have restaurant_id  → check restaurants.is_open
--   • Supermarket orders → have supermarket_id → check supermarkets.is_open
--   • Colis (courier) and Facture orders have NEITHER id → pass untouched.
--
-- Only an EXPLICIT `is_open = false` blocks. A NULL is_open is treated as open
-- (matches the column DEFAULT true and the client's `isOpen ?? true`), so a
-- venue with a null flag is never falsely blocked.
--
-- On rejection it RAISEs the stable, machine-readable message 'VENUE_CLOSED'
-- so the client can map it to a friendly localized error instead of showing a
-- raw SQL string.
--
-- Scope note: this fires ONLY on INSERT of new customer orders. Status UPDATEs
-- (the dispatch waterfall, ghost auto-confirm, cancellation, etc.) are
-- untouched, and no server-side code inserts orders — only the mobile client
-- does — so nothing internal is affected.
--
-- PG15-safe + idempotent: CREATE OR REPLACE FUNCTION, and the trigger creation
-- is guarded by a DO $$ / pg_trigger existence check. Existing order-insert
-- RLS policies are deliberately NOT modified.
-- ============================================================================


-- ── 1. Guard function ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.enforce_venue_open()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_is_open BOOLEAN;
BEGIN
  -- Food order: must target an OPEN restaurant.
  IF NEW.restaurant_id IS NOT NULL THEN
    SELECT is_open INTO v_is_open
    FROM public.restaurants
    WHERE id = NEW.restaurant_id;

    IF v_is_open = FALSE THEN
      RAISE EXCEPTION 'VENUE_CLOSED'
        USING HINT = 'The restaurant is closed and cannot accept orders right now.';
    END IF;

  -- Supermarket order: must target an OPEN supermarket.
  ELSIF NEW.supermarket_id IS NOT NULL THEN
    SELECT is_open INTO v_is_open
    FROM public.supermarkets
    WHERE id = NEW.supermarket_id;

    IF v_is_open = FALSE THEN
      RAISE EXCEPTION 'VENUE_CLOSED'
        USING HINT = 'The supermarket is closed and cannot accept orders right now.';
    END IF;
  END IF;

  -- Colis / Facture (no venue id) fall through here → allowed.
  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enforce_venue_open() TO authenticated, service_role;


-- ── 2. Attach trigger (idempotent, PG15-safe) ────────────────────────────────
-- BEFORE INSERT so a closed-venue order is rejected before the row is written
-- and before the AFTER INSERT push / ghost-confirm triggers ever fire.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'enforce_venue_open'
      AND tgrelid = 'public.orders'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER enforce_venue_open
      BEFORE INSERT ON public.orders
      FOR EACH ROW
      EXECUTE FUNCTION public.enforce_venue_open();
  END IF;
END $$;
