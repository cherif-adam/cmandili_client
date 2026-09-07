-- ============================================================================
-- CMANDILI -- Accept an order offer using the server's own clock
--
-- Bug: the driver app's "Accepter" action claimed the order via a plain
-- PostgREST .update()...gt('assignment_expires_at', <phone's own timestamp>)
-- call. PostgREST filters only compare against the literal value the client
-- sends -- there is no way to reference the database's now() through that
-- path. So the expiry check was effectively decided by the DRIVER'S PHONE
-- CLOCK, not the server. Any clock drift, or simply the network round-trip
-- time between the phone reading DateTime.now() and the request reaching
-- Postgres, could make a still-valid offer get rejected as "expired" (or,
-- in the other direction, let a genuinely-expired one through).
--
-- Fix: move the atomic claim into a SECURITY DEFINER function that compares
-- assignment_expires_at to Postgres's own now() -- mirrors the existing
-- pass_order_offer() function's shape (resolve caller's drivers.id from
-- auth.uid(), single atomic UPDATE ... RETURNING).
--
-- Returns the claimed order id, or NULL if the WHERE clause didn't match
-- (already accepted by someone else, reassigned to another driver, or
-- genuinely expired per the server's clock) -- the caller checks for NULL
-- instead of catching a thrown exception, so a normal "lost the race" case
-- doesn't look like a crash.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.accept_order_offer(p_order_id UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_driver_id   UUID;
  v_claimed_id  UUID;
BEGIN
  SELECT id INTO v_driver_id FROM public.drivers WHERE user_id = auth.uid();
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'caller is not a driver';
  END IF;

  UPDATE public.orders
  SET driver_id = v_driver_id
  WHERE id                  = p_order_id
    AND assigned_driver_id  = v_driver_id
    AND driver_id           IS NULL
    AND assignment_expires_at > now()
  RETURNING id INTO v_claimed_id;

  RETURN v_claimed_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_order_offer(UUID) TO authenticated;
