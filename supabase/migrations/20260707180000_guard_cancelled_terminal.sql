-- ============================================================================
-- CMANDILI — Make 'cancelled' a terminal order status for client-facing roles
--
-- Finding: nothing today stops a customer's/driver's/partner's own
-- 'cancelled' order from being flipped back to 'delivered' (or any other
-- status) via a direct UPDATE — orders_customer_update (RLS,
-- 20260703120000) and guard_orders_column_scope (20260703130000) both allow
-- writes to `status` on rows the caller legitimately owns, with no check on
-- the OLD value. No app flow does this today (the mobile app's only
-- delivered-transition path, "confirm receipt", is gated to
-- status = 'onTheWay'), but nothing at the DB layer blocks a direct API call
-- from doing it — which would incorrectly count a cancelled order toward
-- loyalty_customer_progress.delivered_count via apply_loyalty_program()
-- (20260706171000), and similarly toward generate_settlements_on_delivery.
--
-- Fix: a BEFORE UPDATE guard that rejects OLD.status='cancelled' →
-- NEW.status<>'cancelled' for the same set of callers guard_orders_column_
-- scope already restricts (authenticated/anon), with the same admin
-- exemption. SECURITY DEFINER functions (postgres) and the dashboard/edge
-- functions (service_role) are untouched — matches the exact bypass idiom
-- already used by guard_orders_column_scope, so this stays consistent with
-- the established security model rather than inventing a new one.
--
-- Scope: blocks ALL transitions out of 'cancelled', not just →delivered —
-- cancelled is terminal, full stop (confirmed choice, not narrowed to a
-- single target status).
--
-- Trigger name starts with 'aa_' to run alongside/before
-- aa_guard_orders_column_scope in the same BEFORE-trigger alphabetical
-- ordering band (both are integrity guards that should fire early). Firing
-- order between the two does not affect correctness — neither trigger
-- mutates NEW, both are pure pass-or-reject, so which one fires first only
-- changes which exception message a double-violation surfaces.
--
-- PG15-safe + idempotent: CREATE OR REPLACE FUNCTION + DROP TRIGGER IF
-- EXISTS/CREATE TRIGGER, same pattern as every other migration in this repo.
-- No CREATE POLICY involved — this is a plain trigger, not an RLS policy.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.aa_guard_cancelled_terminal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- Server-side paths (dispatch waterfall, settlements, admin dashboard via
  -- service_role, pg_cron) run as postgres/service_role → untouched.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  -- Admins are unrestricted (same exemption as guard_orders_column_scope).
  IF auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE
  ) THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'cancelled' AND NEW.status IS DISTINCT FROM 'cancelled' THEN
    RAISE EXCEPTION 'Cancelled orders cannot change status (order %)', OLD.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS aa_guard_cancelled_terminal ON public.orders;
CREATE TRIGGER aa_guard_cancelled_terminal
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.aa_guard_cancelled_terminal();
