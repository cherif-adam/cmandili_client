-- ============================================================================
-- CMANDILI -- Fix column-ambiguity bug in dispatch_driver_for_order() (P0)
--
-- Bug: RETURNS TABLE(driver_id uuid, user_id uuid, distance_km double
-- precision) implicitly declares `driver_id` as a PL/pgSQL variable for the
-- whole function body. Two WHERE clauses inside the function reference the
-- *column* orders.driver_id unqualified, which Postgres can no longer
-- resolve (42702: column reference "driver_id" is ambiguous) -- it could
-- mean the output variable or the table column.
--
-- Impact: every call to this function raised a hard SQL error, on every
-- single order. It stayed invisible because push-on-order-status/index.ts
-- calls it as `const { data: dispatch } = await supabase.rpc(...)` without
-- checking `.error` -- a thrown SQL error and "no eligible driver found"
-- both surface identically as `dispatch == null`, so the function's own
-- "No available driver for order X at confirmed" log line has been firing
-- for a totally different reason than it claims. This is THE primary
-- driver-dispatch path (fires when a partner accepts an order), so this
-- bug has been silently breaking auto-dispatch for confirmed orders since
-- whenever this function was first written -- unrelated to and pre-dating
-- today's stuck-order cleanup.
--
-- Fix: qualify both references as public.orders.driver_id. Logic is
-- otherwise byte-identical to the previous version.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.dispatch_driver_for_order(
  p_order_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7,
  p_window_secs INT DEFAULT 30
) RETURNS TABLE(driver_id UUID, user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_driver_id UUID;
  v_lat       DOUBLE PRECISION;
  v_lng       DOUBLE PRECISION;
BEGIN
  -- Bail out if the order already has a driver assigned or accepted.
  PERFORM 1 FROM public.orders
  WHERE id = p_order_id
    AND (public.orders.driver_id IS NOT NULL OR assigned_driver_id IS NOT NULL);
  IF FOUND THEN RETURN; END IF;

  -- Pick the nearest eligible driver.
  v_driver_id := public.next_eligible_driver(p_order_id, p_radius_km);
  IF v_driver_id IS NULL THEN RETURN; END IF;

  -- Atomically assign (only if still unassigned — concurrent-safe).
  UPDATE public.orders
  SET assigned_driver_id    = v_driver_id,
      assignment_expires_at = now() + make_interval(secs => p_window_secs)
  WHERE id                   = p_order_id
    AND public.orders.driver_id IS NULL
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
    d.id                                                            AS driver_id,
    d.user_id                                                       AS user_id,
    public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  WHERE d.id = v_driver_id;
END;
$$;
