-- ============================================================================
-- Migration: Waterfall Dispatch & Timing
-- Purpose: Trigger driver search at "preparing" instead of "ready"
-- ============================================================================

-- 1. Update the fanout trigger to fire on "preparing"
CREATE OR REPLACE FUNCTION public.notify_fcm_fanout_ready_order()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := current_setting('app.edge_function_url',    true);
  v_secret TEXT := current_setting('app.edge_function_secret', true);
BEGIN
  -- We now trigger when status becomes 'preparing'
  IF NEW.status = 'preparing'
     AND (OLD.status IS DISTINCT FROM 'preparing')
     AND v_url IS NOT NULL AND v_url != ''
  THEN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'event',     'driver_fanout',
        'order_id',  NEW.id,
        'status',    NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- The trigger itself stays the same (it watches UPDATE OF status)
-- We just replaced the function logic above.
