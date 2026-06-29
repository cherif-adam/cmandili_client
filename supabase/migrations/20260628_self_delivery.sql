-- ============================================================================
-- Migration: Self-delivery fallback when no drivers accept an order
--
-- When the dispatch waterfall exhausts all nearby drivers (every driver
-- either rejected the offer or didn't respond within their window, and
-- next_eligible_driver returns NULL), the partner is notified via FCM so
-- they can choose to deliver the order themselves.
--
-- New columns on orders:
--   self_delivery          BOOLEAN  — partner chose to self-deliver
--   no_driver_notified_at  TIMESTAMPTZ — when we first notified the partner
--                                        (guard against duplicate pushes)
--
-- Changes:
--   1. New columns on orders table
--   2. notify_partner_no_drivers() — guarded HTTP push to edge function
--   3. rotate_expired_offers() — ELSE branch calls notify_partner_no_drivers
--   4. pass_order_offer()      — ELSE branch calls notify_partner_no_drivers
--   5. generate_settlements_on_delivery() — driver_fee_cut = 0 for self-delivery
-- ============================================================================


-- ── 1. New columns ───────────────────────────────────────────────────────────

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS self_delivery         BOOLEAN    NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS no_driver_notified_at TIMESTAMPTZ;


-- ── 2. notify_partner_no_drivers ─────────────────────────────────────────────
-- Called from rotate_expired_offers and pass_order_offer when no eligible
-- driver is found. Guards against double-notification using no_driver_notified_at.

CREATE OR REPLACE FUNCTION public.notify_partner_no_drivers(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url',    TRUE),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', TRUE),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
  v_driver_id          UUID;
  v_already_notified   BOOLEAN;
BEGIN
  -- Read current state; bail out if a driver already accepted or we already notified.
  SELECT driver_id, (no_driver_notified_at IS NOT NULL)
    INTO v_driver_id, v_already_notified
    FROM public.orders WHERE id = p_order_id;

  IF v_driver_id IS NOT NULL OR v_already_notified THEN
    RETURN;
  END IF;

  -- Atomically stamp the notification timestamp (prevents races with another
  -- concurrent cron/pass execution for the same order).
  UPDATE public.orders
     SET no_driver_notified_at = now()
   WHERE id = p_order_id
     AND driver_id            IS NULL
     AND no_driver_notified_at IS NULL;

  IF NOT FOUND THEN
    RETURN; -- lost the race — another process already notified
  END IF;

  -- Call the edge function; it will look up the partner and push FCM.
  PERFORM net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body    := jsonb_build_object(
      'event',    'no_drivers',
      'order_id', p_order_id,
      'status',   'no_drivers'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_partner_no_drivers(UUID) TO service_role;


-- ── 3. Patch rotate_expired_offers ───────────────────────────────────────────
-- Add ELSE branch: when next_eligible_driver returns NULL after a driver's
-- window expires, notify the partner instead of leaving the order silent.

CREATE OR REPLACE FUNCTION public.rotate_expired_offers()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row   RECORD;
  v_count INTEGER := 0;
  v_next  UUID;
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
    IF v_next IS NOT NULL THEN
      PERFORM public.offer_order_to_driver(v_row.id, v_next);
    ELSE
      -- Waterfall exhausted: no more eligible drivers found after this rejection.
      -- Notify the partner so they can choose to self-deliver.
      PERFORM public.notify_partner_no_drivers(v_row.id);
    END IF;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rotate_expired_offers() TO service_role;


-- ── 4. Patch pass_order_offer ─────────────────────────────────────────────────
-- Add ELSE branch: same logic as above but triggered synchronously when a
-- driver explicitly taps "Pass" before the timer expires.

CREATE OR REPLACE FUNCTION public.pass_order_offer(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_driver UUID;
  v_current       UUID;
  v_next          UUID;
BEGIN
  SELECT id INTO v_caller_driver FROM public.drivers WHERE user_id = auth.uid();
  IF v_caller_driver IS NULL THEN
    RAISE EXCEPTION 'caller is not a driver';
  END IF;

  SELECT assigned_driver_id INTO v_current
  FROM public.orders WHERE id = p_order_id;
  IF v_current IS DISTINCT FROM v_caller_driver THEN
    -- Caller isn't the currently-offered driver: noop, don't punish them.
    RETURN;
  END IF;

  UPDATE public.orders
  SET passed_driver_ids    = passed_driver_ids || v_caller_driver,
      assigned_driver_id   = NULL,
      assignment_expires_at = NULL
  WHERE id = p_order_id;

  v_next := public.next_eligible_driver(p_order_id);
  IF v_next IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(p_order_id, v_next);
  ELSE
    -- Waterfall exhausted: this driver was the last one available.
    -- Notify the partner so they can choose to self-deliver.
    PERFORM public.notify_partner_no_drivers(p_order_id);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pass_order_offer(UUID) TO authenticated;


-- ── 5. Patch generate_settlements_on_delivery ─────────────────────────────────
-- Self-delivered orders: platform_fee (restaurant commission) unchanged,
-- but driver_fee_cut = 0 because no driver was involved.
-- The existing guard `IF NEW.driver_id IS NOT NULL` already skips the
-- driver settlement row for self-delivery; we only need to zero the fee stamp.

CREATE OR REPLACE FUNCTION public.generate_settlements_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission     NUMERIC(12,3);
  v_partner_user_id       UUID;
  v_restaurant_rate       NUMERIC(5,4);
  v_driver_rate           NUMERIC(5,4);
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' AND NEW.payment_method = 'cash' THEN

    -- Read live rates from global_settings (falls back to hardcoded defaults)
    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_restaurant_commission_rate'),
        0.10
    ) INTO v_restaurant_rate;

    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_driver_commission_rate'),
        0.23
    ) INTO v_driver_rate;

    -- A) Resolve partner user_id
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- B) Calculate cuts
    v_restaurant_commission := NEW.subtotal * v_restaurant_rate;
    -- Self-delivered orders: no driver involved, driver cut is zero
    IF NEW.self_delivery THEN
      v_driver_commission := 0;
    ELSE
      v_driver_commission := NEW.delivery_fee * v_driver_rate;
    END IF;

    -- C) Stamp the order
    UPDATE public.orders
       SET platform_fee   = v_restaurant_commission,
           driver_fee_cut = v_driver_commission
     WHERE id = NEW.id;

    -- D) Partner settlement: Platform owes Partner (Subtotal − Commission)
    IF v_partner_user_id IS NOT NULL THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_partner_user_id,
        'restaurant',
        (NEW.subtotal - v_restaurant_commission),
        'order_earning',
        'Vente commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'pending'
      );
    END IF;

    -- E) Driver settlement: only for driver-delivered orders
    --    (driver_id IS NULL for self-delivered orders, so this guard is
    --    sufficient — but explicit self_delivery check makes intent clear)
    IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        NEW.driver_id,
        'driver',
        -((NEW.subtotal - v_restaurant_commission) + v_driver_commission),
        'commission_deduction',
        'Collecte cash commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'pending'
      );
    END IF;

  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_delivered_settlements ON public.orders;
CREATE TRIGGER on_order_delivered_settlements
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.generate_settlements_on_delivery();
