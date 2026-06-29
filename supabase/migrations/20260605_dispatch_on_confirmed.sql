-- ============================================================================
-- CMANDILI — Two fixes:
--
--   1. next_eligible_driver: add "not on an active delivery" filter so a
--      driver who already has a live order in hand (confirmed→onTheWay) is
--      never offered a second one.
--
--   2. dispatch_driver_for_order: new helper called by the edge function when
--      an order reaches 'confirmed' status. Wraps next_eligible_driver +
--      order-assignment in one atomic DB call so the edge function stays thin.
--      Returns the assigned drivers.id (UUID) or NULL if no driver is available.
--
-- Idempotent — safe to re-run.
-- ============================================================================


-- ── 1. Patch next_eligible_driver ────────────────────────────────────────────
-- Add NOT EXISTS sub-select to exclude drivers with an active delivery.
-- Active = driver_id matches AND status has not reached 'delivered'/'cancelled'.

CREATE OR REPLACE FUNCTION public.next_eligible_driver(
  p_order_id  UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_lat       DOUBLE PRECISION;
  v_lng       DOUBLE PRECISION;
  v_passed    UUID[];
  v_driver_id UUID;
BEGIN
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION),
    o.passed_driver_ids
  INTO v_lat, v_lng, v_passed
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
    RETURN NULL;
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.is_online      = TRUE
    AND d.current_lat   IS NOT NULL
    AND d.current_lng   IS NOT NULL
    AND public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT (d.id = ANY(COALESCE(v_passed, '{}'::UUID[])))
    -- ── NEW: skip drivers who are already handling a live delivery ──────────
    AND NOT EXISTS (
      SELECT 1
      FROM   public.orders active
      WHERE  active.driver_id = d.id
        AND  active.status IN ('confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay')
    )
    -- ── also skip drivers who currently have an un-expired offer pending ────
    AND NOT EXISTS (
      SELECT 1
      FROM   public.orders offered
      WHERE  offered.assigned_driver_id = d.id
        AND  offered.driver_id          IS NULL
        AND  offered.assignment_expires_at > now()
    )
  ORDER BY public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) ASC
  LIMIT 1;

  RETURN v_driver_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_eligible_driver(UUID, DOUBLE PRECISION)
  TO anon, authenticated, service_role;


-- ── 2. dispatch_driver_for_order ─────────────────────────────────────────────
-- Called by the edge function immediately after an order is confirmed.
-- Finds the nearest available driver, writes the assignment, and returns
-- the driver's drivers.id + user_id so the edge function can push FCM.
-- Returns NULL if no driver is available right now (cron rotation will retry).

CREATE OR REPLACE FUNCTION public.dispatch_driver_for_order(
  p_order_id      UUID,
  p_radius_km     DOUBLE PRECISION DEFAULT 7,
  p_window_secs   INT              DEFAULT 30
)
RETURNS TABLE(driver_id UUID, user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_driver_id UUID;
  v_lat       DOUBLE PRECISION;
  v_lng       DOUBLE PRECISION;
BEGIN
  -- Bail out if the order already has a driver assigned or accepted.
  PERFORM 1 FROM public.orders
  WHERE id = p_order_id
    AND (driver_id IS NOT NULL OR assigned_driver_id IS NOT NULL);
  IF FOUND THEN RETURN; END IF;

  -- Pick the nearest eligible driver.
  v_driver_id := public.next_eligible_driver(p_order_id, p_radius_km);
  IF v_driver_id IS NULL THEN RETURN; END IF;

  -- Atomically assign (only if still unassigned — concurrent-safe).
  UPDATE public.orders
  SET assigned_driver_id   = v_driver_id,
      assignment_expires_at = now() + make_interval(secs => p_window_secs)
  WHERE id          = p_order_id
    AND driver_id   IS NULL
    AND (assigned_driver_id IS NULL OR assignment_expires_at < now());

  IF NOT FOUND THEN
    -- Lost the race — another process assigned first.
    RETURN;
  END IF;

  -- Compute distance for the caller to surface to the driver.
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION)
  INTO v_lat, v_lng
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  RETURN QUERY
  SELECT
    d.id                                                           AS driver_id,
    d.user_id                                                      AS user_id,
    public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  WHERE d.id = v_driver_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_driver_for_order(UUID, DOUBLE PRECISION, INT)
  TO service_role;
