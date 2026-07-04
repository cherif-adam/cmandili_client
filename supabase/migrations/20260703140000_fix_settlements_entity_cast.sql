-- ============================================================================
-- CMANDILI — Fix uuid=text crash in generate_settlements_on_delivery (P0)
--
-- Discovered while verifying Fix #3c (self-delivery status mismatch) end to
-- end: the live settlements trigger resolves the partner with
--
--     WHERE entity_id = NEW.restaurant_id::text
--
-- but partners.entity_id is UUID in the live DB (it was TEXT in the original
-- schema file; the column was later converted). uuid = text has no operator,
-- so the trigger raises 42883 at runtime — which ABORTS the status→delivered
-- UPDATE for every CASH order at a restaurant/supermarket venue: the driver's
-- "Confirm Delivery", the partner's self-delivery completion, and the
-- customer's "confirm receipt" all fail, and no settlements are generated.
-- (plpgsql bodies are only parsed at execution, so the 20260628 migrations
-- deployed this without error.)
--
-- Fix: byte-identical redefinition of the function (same logic, same
-- SECURITY DEFINER, same rates/self-delivery handling as the live version
-- from 20260628_self_delivery.sql) with ONLY the two comparisons changed to
--
--     WHERE entity_id::text = NEW.restaurant_id::text
--
-- which is valid whether entity_id is UUID (live) or TEXT (schema file).
-- Nothing else (waterfall, statuses, RLS, the aa_ column guard) is touched.
-- Idempotent — CREATE OR REPLACE.
-- ============================================================================

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
    --    entity_id::text works for both the live UUID column and the
    --    original TEXT definition — never compare uuid = text directly.
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.supermarket_id::text LIMIT 1;
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
