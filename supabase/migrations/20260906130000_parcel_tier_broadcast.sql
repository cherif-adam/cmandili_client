-- ============================================================================
-- CMANDILI -- Two-tier broadcast for parcel/facture orders
--
-- Tier 1 (sent immediately on order creation): broadcast ONLY to drivers who
-- are online AND have no active order right now (same "active" status list
-- already used by next_eligible_driver for the food cascade).
--
-- Tier 2 (fallback): if nobody in tier 1 has accepted within 30 seconds, a
-- cron job widens the broadcast to ALL online eligible drivers, busy or not.
-- Sent at most once per order, guarded by parcel_tier2_sent_at the same way
-- notify_partner_no_drivers guards against duplicate "no drivers" pushes.
-- ============================================================================

-- ── 1. New columns on orders ────────────────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS parcel_tier1_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS parcel_tier2_sent_at     TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_orders_parcel_tier1_pending
  ON public.orders (parcel_tier1_expires_at)
  WHERE driver_id IS NULL AND parcel_tier2_sent_at IS NULL;


-- ── 2. RPC: nearby ONLINE + FREE drivers (tier 1 pool) ──────────────────────
-- Same shape as nearby_online_drivers, plus the same "not already on an
-- active delivery" exclusion next_eligible_driver already uses for food.
CREATE OR REPLACE FUNCTION public.nearby_online_free_drivers(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS TABLE(user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT
    d.user_id,
    public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  WHERE d.is_online = true
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT EXISTS (
      SELECT 1 FROM public.orders active
      WHERE active.driver_id = d.id
        AND active.status IN ('confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay')
    )
  ORDER BY distance_km ASC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_online_free_drivers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  TO service_role;


-- ── 3. Patch notify_fcm_on_new_order: stamp tier-1 deadline, tag the push ───
-- Only the courier/facture ('ready' at birth) branch changes -- the food/
-- supermarket ('pending' at birth) branch is byte-identical to before.
CREATE OR REPLACE FUNCTION public.notify_fcm_on_new_order()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
BEGIN
  IF NEW.status = 'ready' THEN
    -- Courier/facture: born 'ready', no partner, no 'confirmed' step ever
    -- happens. Stamp the tier-1 deadline so the escalation cron knows when
    -- it's allowed to widen to busy drivers, then send the tier-1 (free
    -- drivers only) broadcast.
    UPDATE public.orders
    SET parcel_tier1_expires_at = now() + interval '30 seconds'
    WHERE id = NEW.id;

    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'event',    'driver_fanout',
        'order_id', NEW.id,
        'status',   NEW.status,
        'tier',     '1'
      )
    );
  ELSE
    -- Food/supermarket: born 'pending' -- standard status-change payload,
    -- which is what fires the partner's new-order alarm. Unchanged.
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'order_id', NEW.id,
        'status',   NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$;


-- ── 4. Escalation cron: widen to tier 2 once the tier-1 window has passed ───
CREATE OR REPLACE FUNCTION public.escalate_parcel_broadcast_tier()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
  v_row   RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id FROM public.orders
    WHERE order_type IN ('courier', 'facture')
      AND status = 'ready'
      AND driver_id IS NULL
      AND parcel_tier1_expires_at IS NOT NULL
      AND parcel_tier1_expires_at < now()
      AND parcel_tier2_sent_at IS NULL
    LIMIT 20
  LOOP
    -- Stamp first (atomically guards against double-send if this tick
    -- somehow overlaps a concurrent run) then push.
    UPDATE public.orders
    SET parcel_tier2_sent_at = now()
    WHERE id = v_row.id AND parcel_tier2_sent_at IS NULL;

    IF FOUND THEN
      PERFORM net.http_post(
        url     := v_url,
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_secret
        ),
        body    := jsonb_build_object(
          'event',    'driver_fanout',
          'order_id', v_row.id,
          'status',   'ready',
          'tier',     '2'
        )
      );
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.escalate_parcel_broadcast_tier() TO service_role;

SELECT cron.schedule(
  'escalate-parcel-tier',
  '10 seconds',
  $$SELECT public.escalate_parcel_broadcast_tier();$$
);
