-- ============================================================================
-- CMANDILI — Make 'delivered' a terminal order status for client-facing roles
--
-- Finding: generate_settlements_on_delivery (20260814090000_loyalty_at_
-- checkout.sql and its predecessors back to 20260512_wallets_and_balances.sql)
-- fires on `NEW.status = 'delivered' AND OLD.status != 'delivered'`. That
-- guard only stops a no-op re-save while already delivered — it does NOT
-- stop an order from being moved OUT of 'delivered' and back IN. The driver
-- RLS UPDATE policy (orders_driver_update_own, 20260703120000) and the
-- column-scope guard (guard_orders_column_scope, 20260703130000) both permit
-- a driver to write `status` on their own order with no transition-graph
-- check — that guard's own header comment says validating transition VALUES
-- is explicitly out of its scope.
--
-- The existing aa_guard_cancelled_terminal (20260707180000) closed this
-- exact class of bug for 'cancelled' but was scoped narrowly to that one
-- status; 'delivered' was left open. A direct API replay —
-- UPDATE orders SET status='onTheWay' ... ; UPDATE orders SET
-- status='delivered' ... a second time — re-fires
-- generate_settlements_on_delivery, inserting a SECOND negative
-- commission_deduction settlement (double-charging the restaurant/driver
-- prepaid wallet) and, for loyalty-milestone orders, a SECOND positive
-- loyalty_subsidy credit. Real double-charge/double-credit vector, entirely
-- independent of any client-side UI guard.
--
-- Fix: same trigger idiom as aa_guard_cancelled_terminal — reject
-- OLD.status='delivered' -> NEW.status<>'delivered' for authenticated/anon,
-- with the same admin + server-role (postgres/service_role) exemptions.
-- Deliberately a SEPARATE trigger (not a merge into
-- aa_guard_cancelled_terminal) so this stays a small, independently
-- reviewable/revertable change.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.aa_guard_delivered_terminal()
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

  -- Admins are unrestricted (same exemption as guard_orders_column_scope
  -- and aa_guard_cancelled_terminal).
  IF auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE
  ) THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'delivered' AND NEW.status IS DISTINCT FROM 'delivered' THEN
    RAISE EXCEPTION 'Delivered orders cannot change status (order %)', OLD.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS aa_guard_delivered_terminal ON public.orders;
CREATE TRIGGER aa_guard_delivered_terminal
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.aa_guard_delivered_terminal();
