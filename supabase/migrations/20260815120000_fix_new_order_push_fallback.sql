-- ============================================================================
-- CMANDILI -- Fix silent no-op in notify_fcm_on_new_order() (P0)
--
-- Bug: unlike its two siblings (notify_fcm_fanout_ready_order,
-- notify_fcm_on_order_status), this AFTER INSERT trigger read
-- current_setting('app.edge_function_url', true) with NO fallback. Since
-- that setting is unset at the DB level, v_url was NULL, its
-- "IF v_url IS NOT NULL AND v_url != ''" guard was false, and net.http_post
-- was never even called -- every single order creation silently skipped its
-- push, with no error anywhere to signal it.
--
-- Confirmed via pg_net's response log (empty for today's activity) and by
-- tracing a real stuck test order: status='pending', driver_id=NULL. The
-- partner "new order" alert that should fire on INSERT never fired, so the
-- partner never confirmed it, so the driver-dispatch step (which only runs
-- once status reaches 'confirmed', via the *working* sibling trigger) never
-- got a chance to run. Nothing downstream was broken -- the chain never
-- started.
--
-- Second, structural fix bundled in: courier/facture orders are created
-- directly with status='ready' (never 'pending'->'confirmed'), so their only
-- possible driver-dispatch path is the driver_fanout event -- but that only
-- existed in the UPDATE-based trigger, which can never fire for them since
-- they're born already 'ready' (no UPDATE transition into it ever happens).
-- This migration makes the INSERT trigger route status='ready' orders into
-- the same driver_fanout event its UPDATE sibling uses, so courier/facture
-- orders get a real dispatch attempt at creation time.
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
    body    := CASE WHEN NEW.status = 'ready'
                 -- Courier/facture: born 'ready', no partner, no 'confirmed'
                 -- step ever happens -- fan out to nearby drivers right now,
                 -- same event/payload shape as notify_fcm_fanout_ready_order.
                 THEN jsonb_build_object(
                        'event',    'driver_fanout',
                        'order_id', NEW.id,
                        'status',   NEW.status
                      )
                 -- Food/supermarket: born 'pending' -- standard status-change
                 -- payload, which is what fires the partner's new-order alarm.
                 ELSE jsonb_build_object(
                        'order_id', NEW.id,
                        'status',   NEW.status
                      )
               END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger already exists (on_order_insert_push) and points at this function
-- by name; CREATE OR REPLACE above is enough, no re-attach needed.
