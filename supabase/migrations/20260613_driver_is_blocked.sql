-- ============================================================================
-- Migration: Add is_blocked to drivers table
-- Purpose: Allow admin to block drivers from receiving new order offers.
--          The dispatch RPCs are updated to skip blocked drivers.
-- ============================================================================

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT FALSE;

-- Update next_eligible_driver to skip blocked drivers
CREATE OR REPLACE FUNCTION public.next_eligible_driver(
  p_order_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_passed UUID[];
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
  WHERE d.is_online = TRUE
    AND d.is_blocked = FALSE
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT (d.id = ANY(v_passed))
  ORDER BY public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) ASC
  LIMIT 1;

  RETURN v_driver_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_eligible_driver(UUID, DOUBLE PRECISION)
  TO anon, authenticated, service_role;

-- Allow service_role to update is_blocked
GRANT UPDATE (is_blocked) ON public.drivers TO service_role;
