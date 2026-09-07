-- ============================================================================
-- CMANDILI -- Restore the missing push in offer_order_to_driver()
--
-- Root cause (confirmed via pg_get_triggerdef + pg_get_functiondef + live
-- net._http_response logs, 2026-09-07): offer_order_to_driver() only ever
-- UPDATEs assigned_driver_id / assignment_expires_at, never `status`. The
-- ONLY trigger wired to call the push edge function is
-- on_order_status_push, defined as `AFTER UPDATE OF status ... IF
-- NEW.status != OLD.status`. So every call to offer_order_to_driver() has
-- been silently DB-only — no push ever went out.
--
-- This is a regression, not a gap in the original design: the edge
-- function's push-on-order-status/index.ts already has a "Mode C" handler
-- (`if (event === 'offer_to_driver')`) whose own comment says "Triggered by
-- the offer_order_to_driver RPC" -- it has been sitting there, unreachable,
-- since whichever migration last replaced this function body without
-- carrying the net.http_post call forward. Mode C already looks up
-- assigned_driver_id and the driver's user_id itself, so the SQL side only
-- needs to send {event, order_id, status} -- restoring exactly the call
-- Mode C was built to receive. No edge function or client-side change
-- needed.
--
-- This fixes every current caller of offer_order_to_driver(), not just the
-- reported one:
--   - rotate_expired_offers()          -- food cascade rotation (reported bug)
--   - notify_fcm_fanout_ready_order()  -- legacy/secondary food path
--   - ghost-restaurant / ghost-supermarket auto-confirm triggers
--   - self_delivery's re-offering logic
-- ============================================================================

CREATE OR REPLACE FUNCTION public.offer_order_to_driver(
  p_order_id UUID,
  p_driver_id UUID,
  p_window_seconds INTEGER DEFAULT 30
) RETURNS void
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
  v_status TEXT;
BEGIN
  UPDATE public.orders
  SET assigned_driver_id    = p_driver_id,
      assignment_expires_at = now() + make_interval(secs => p_window_seconds)
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

GRANT EXECUTE ON FUNCTION public.offer_order_to_driver(UUID, UUID, INTEGER)
  TO authenticated, service_role;
