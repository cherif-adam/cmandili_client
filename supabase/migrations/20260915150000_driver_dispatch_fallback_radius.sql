-- ============================================================================
-- CMANDILI -- Driver dispatch: 20km fallback radius + accurate offer distance
--
-- Problem: dispatch_driver_for_order() / rotate_expired_offers() only ever
-- search within 7km. If literally zero eligible drivers exist that close,
-- the order either sits until the next waterfall tick finds the same empty
-- result (rotation path) or -- worse -- is never retried or notified at all
-- (initial-dispatch path, see bug below). Food's real freshness constraint
-- justifies keeping 7km as the DEFAULT, but a one-time widen-and-retry
-- before giving up entirely is a reasonable safety net, as long as the
-- driver clearly sees they're being offered something farther than usual.
--
-- Fix: when next_eligible_driver() finds nobody within the normal radius,
-- try once more at a wider radius (tunable, see below) before giving up.
-- Same eligibility rule at a larger radius -- not a different one: a driver
-- who's online, in range, hasn't already passed on this order, and isn't
-- already busy/offered elsewhere. This is exactly "zero eligible drivers
-- within 7km" as next_eligible_driver() already defines it today.
--
-- Tunable radius: DRIVER_FANOUT_RADIUS_KM (the existing 7km default) is a
-- Deno env var read inside the push-on-order-status edge function --
-- useless here because rotate_expired_offers() is invoked directly by
-- pg_cron with no HTTP/edge-function hop, so it has no way to read it. The
-- codebase's OTHER constant mechanism, current_setting('app.edge_function_url'
-- / 'app.edge_function_secret', true) (see notify_partner_no_drivers(),
-- offer_order_to_driver(), escalate_parcel_broadcast_tier()), turns out to
-- be dead in this project too: 20260426_set_edge_function_settings.sql's
-- `ALTER DATABASE ... SET app.*` requires superuser, which Supabase Cloud's
-- migration runner doesn't have -- confirmed that statement has always
-- silently failed there (caught by its own EXCEPTION block), so every
-- function reading those settings has always used its hardcoded fallback,
-- never an actually-configured value. Using public.global_settings instead
-- (the table already backing rush_hour_multiplier / commission rates) --
-- a plain row, readable identically from the cron path and the dispatch
-- path, tunable via an ordinary UPDATE, no superuser required.
--
-- Bug #1 fixed: dispatch_driver_for_order() previously just RETURNed (no
-- driver, no notification) when next_eligible_driver() found nobody on the
-- FIRST attempt. That order never gets an assigned_driver_id, so it never
-- matches rotate_expired_offers()'s WHERE assigned_driver_id IS NOT NULL --
-- it was silently never retried and the partner was never told, despite the
-- edge function's own log line claiming "cron will retry". Now: try the
-- wider radius, and if that's ALSO empty, call notify_partner_no_drivers()
-- directly (idempotent/race-safe already, confirmed from its own source).
--
-- Bug #2 fixed: OrderOfferDialog (driver app) reads a `distance_km` column
-- that does not exist on `orders` at all (confirmed live -- the exact
-- select the dialog runs errors with 42703 column "distance_km" does not
-- exist). Every single offer dialog has therefore been failing to load
-- order details and falling back to its generic "Could not load order
-- details" message. Separately, orders.createOrder()'s `distanceKm` param
-- (checkout_screen.dart) was ALSO dead -- accepted but never written to any
-- column -- so there was never a real distance value here to begin with,
-- correct or not. New columns below (driver_offer_distance_km,
-- driver_offer_is_fallback) are populated at the moment each offer is
-- created (both the initial dispatch and each waterfall rotation), with the
-- driver's own haversine distance to the pickup point -- the value
-- next_eligible_driver() already computes for eligibility but never
-- persisted anywhere readable.
--
-- PG15-safe + idempotent (ON CONFLICT DO NOTHING, ADD COLUMN IF NOT EXISTS,
-- CREATE OR REPLACE FUNCTION).
-- ============================================================================


-- ── 1. Tunable fallback radius, stored the way this codebase actually
--       supports runtime-tunable constants ──────────────────────────────────

INSERT INTO public.global_settings (setting_key, setting_value, description)
VALUES (
  'driver_fallback_radius_km',
  '20',
  'Widened search radius (km) tried once when zero eligible drivers exist within the normal dispatch radius. Change with a plain UPDATE -- no redeploy needed.'
)
ON CONFLICT (setting_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.driver_fallback_radius_km()
RETURNS DOUBLE PRECISION
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    (SELECT setting_value::DOUBLE PRECISION
       FROM public.global_settings
      WHERE setting_key = 'driver_fallback_radius_km'),
    20
  );
$$;


-- ── 2. Where the driver's real distance to pickup gets persisted ───────────

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS driver_offer_distance_km DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS driver_offer_is_fallback BOOLEAN NOT NULL DEFAULT false;


-- ── 3. offer_order_to_driver(): now also stamps the driver's distance to
--       pickup and whether this offer came from the fallback radius. Used by
--       rotate_expired_offers() for every waterfall-retry offer -- this
--       previously computed no distance at all for that path.
--
--       Adding a 4th parameter changes this function's arg-type signature
--       ((uuid,uuid,integer) -> (uuid,uuid,integer,boolean)), so
--       CREATE OR REPLACE would create a second overload rather than
--       replace the old one -- drop the old signature explicitly first. ───

DROP FUNCTION IF EXISTS public.offer_order_to_driver(uuid, uuid, integer);

CREATE OR REPLACE FUNCTION public.offer_order_to_driver(
  p_order_id uuid,
  p_driver_id uuid,
  p_window_seconds integer DEFAULT 30,
  p_is_fallback boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
  v_status   TEXT;
  v_lat      DOUBLE PRECISION;
  v_lng      DOUBLE PRECISION;
  v_distance DOUBLE PRECISION;
BEGIN
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION)
  INTO v_lat, v_lng
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  SELECT public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng)
    INTO v_distance
    FROM public.drivers d
   WHERE d.id = p_driver_id;

  UPDATE public.orders
  SET assigned_driver_id       = p_driver_id,
      assignment_expires_at    = now() + make_interval(secs => p_window_seconds),
      driver_offer_distance_km = v_distance,
      driver_offer_is_fallback = p_is_fallback
  WHERE id = p_order_id
    AND driver_id IS NULL
  RETURNING status INTO v_status;

  -- v_status is NULL if the UPDATE matched no row -- e.g. a concurrent
  -- accept already set driver_id between the caller's SELECT and this
  -- UPDATE (the same race dispatch_driver_for_order already guards
  -- against). Don't push an offer for an order that's already taken.
  IF v_status IS NOT NULL THEN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'event',    'offer_to_driver',
        'order_id', p_order_id,
        'status',   v_status
      )
    );
  END IF;
END;
$$;


-- ── 4. dispatch_driver_for_order(): try the normal radius, then the
--       tunable fallback radius, then -- if still nobody -- notify the
--       partner directly instead of silently doing nothing (bug #1).
--
--       Adding the is_fallback output column changes this function's
--       RETURNS TABLE row type, which CREATE OR REPLACE refuses outright
--       (42P13: cannot change return type of existing function) -- drop it
--       first, same as above. ─────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.dispatch_driver_for_order(uuid, double precision, integer);

CREATE OR REPLACE FUNCTION public.dispatch_driver_for_order(
  p_order_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7,
  p_window_secs INT DEFAULT 30
) RETURNS TABLE(driver_id UUID, user_id UUID, distance_km DOUBLE PRECISION, is_fallback BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_driver_id     UUID;
  v_lat           DOUBLE PRECISION;
  v_lng           DOUBLE PRECISION;
  v_distance      DOUBLE PRECISION;
  v_used_fallback BOOLEAN := false;
BEGIN
  -- Bail out if the order already has a driver assigned or accepted.
  PERFORM 1 FROM public.orders
  WHERE id = p_order_id
    AND (public.orders.driver_id IS NOT NULL OR assigned_driver_id IS NOT NULL);
  IF FOUND THEN RETURN; END IF;

  -- Resolve pickup coords once -- needed below regardless of which radius
  -- ends up finding a driver.
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION)
  INTO v_lat, v_lng
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  -- Pick the nearest eligible driver within the normal radius.
  v_driver_id := public.next_eligible_driver(p_order_id, p_radius_km);

  IF v_driver_id IS NULL THEN
    -- Nobody eligible that close -- widen the net once, same eligibility
    -- rule, before giving up.
    v_driver_id := public.next_eligible_driver(p_order_id, public.driver_fallback_radius_km());
    v_used_fallback := v_driver_id IS NOT NULL;
  END IF;

  IF v_driver_id IS NULL THEN
    -- Exhausted even the wider radius. Previously this just RETURNed here,
    -- relying on rotate_expired_offers() to retry later -- but an order
    -- that never got a first assignment never enters that cron's WHERE
    -- assigned_driver_id IS NOT NULL clause, so it was never actually
    -- retried or reported. Tell the partner now instead.
    PERFORM public.notify_partner_no_drivers(p_order_id);
    RETURN;
  END IF;

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

  SELECT public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng)
    INTO v_distance
    FROM public.drivers d
   WHERE d.id = v_driver_id;

  UPDATE public.orders
  SET driver_offer_distance_km = v_distance,
      driver_offer_is_fallback = v_used_fallback
  WHERE id = p_order_id;

  RETURN QUERY
  SELECT
    d.id       AS driver_id,
    d.user_id  AS user_id,
    v_distance AS distance_km,
    v_used_fallback AS is_fallback
  FROM public.drivers d
  WHERE d.id = v_driver_id;
END;
$$;


-- ── 5. rotate_expired_offers(): same widen-then-give-up pattern for the
--       waterfall-retry path. ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rotate_expired_offers()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row           RECORD;
  v_count         INTEGER := 0;
  v_next          UUID;
  v_used_fallback BOOLEAN;
BEGIN
  FOR v_row IN
    SELECT id, assigned_driver_id
    FROM public.orders
    WHERE assigned_driver_id IS NOT NULL
      AND driver_id IS NULL
      AND assignment_expires_at IS NOT NULL
      AND assignment_expires_at < now()
    LIMIT 20
  LOOP
    -- Mark current candidate as passed before picking the next one so the
    -- query for next_eligible_driver sees a consistent passed_driver_ids array.
    UPDATE public.orders
    SET passed_driver_ids    = passed_driver_ids || v_row.assigned_driver_id,
        assigned_driver_id   = NULL,
        assignment_expires_at = NULL
    WHERE id = v_row.id;

    v_next := public.next_eligible_driver(v_row.id);
    v_used_fallback := false;

    IF v_next IS NULL THEN
      v_next := public.next_eligible_driver(v_row.id, public.driver_fallback_radius_km());
      v_used_fallback := v_next IS NOT NULL;
    END IF;

    IF v_next IS NOT NULL THEN
      PERFORM public.offer_order_to_driver(v_row.id, v_next, 30, v_used_fallback);
    ELSE
      -- Waterfall exhausted at both radii: no more eligible drivers found.
      -- Notify the partner so they can choose to self-deliver.
      PERFORM public.notify_partner_no_drivers(v_row.id);
    END IF;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
