-- ============================================================================
-- Fix: notify_fcm_on_new_order was missing the inline URL fallback.
--
-- The GUC (app.edge_function_url) is set via ALTER DATABASE which requires
-- superuser. On Supabase Cloud the SQL editor is not superuser, so the ALTER
-- is silently blocked. The UPDATE trigger (notify_fcm_on_order_status) has a
-- COALESCE fallback and works. The INSERT trigger added in 20260507 did not
-- have the fallback, so v_url was always NULL and the IF guard always skipped
-- the http_post — no partner notification was ever sent for new orders.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_fcm_on_new_order()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url',    true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
BEGIN
  PERFORM net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body    := jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
