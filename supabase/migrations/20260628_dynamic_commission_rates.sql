-- ============================================================================
-- Migration: Dynamic Commission Rates
-- Purpose: Update global_settings to match actual rates used in production,
--          and rewrite the settlement trigger to read rates from global_settings
--          instead of hardcoded constants.
--
-- After this migration, changing a rate in the admin Settings page
-- takes effect on all NEW orders without touching past records.
-- ============================================================================

-- 1. Correct the commission rate defaults in global_settings to match
--    what the trigger was actually using (0.10 / 0.23).
INSERT INTO public.global_settings (setting_key, setting_value, description)
VALUES
  ('default_restaurant_commission_rate', '0.10', 'Platform commission taken from restaurant subtotal (e.g. 0.10 = 10%)'),
  ('default_supermarket_commission_rate', '0.10', 'Platform commission taken from supermarket subtotal (e.g. 0.10 = 10%)'),
  ('default_driver_commission_rate',     '0.23', 'Platform commission taken from driver delivery fee (e.g. 0.23 = 23%)')
ON CONFLICT (setting_key) DO UPDATE
  SET setting_value = EXCLUDED.setting_value,
      description   = EXCLUDED.description;


-- 2. Allow service_role to UPDATE global_settings (needed by admin Settings page)
GRANT SELECT, UPDATE ON public.global_settings TO service_role;


-- 3. Replace the settlement trigger function to read rates from global_settings.
--    Logic is identical to the original — only the rate variables change.
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

    -- Read live rates from global_settings (falls back to hardcoded defaults if rows missing)
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

    -- B) Calculate cuts using live rates
    v_restaurant_commission := NEW.subtotal * v_restaurant_rate;
    v_driver_commission     := NEW.delivery_fee * v_driver_rate;

    -- C) Stamp the order with the calculated fees (non-retroactive: only this order)
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

    -- E) Driver settlement: Driver owes Platform
    IF NEW.driver_id IS NOT NULL THEN
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

-- Trigger already exists from previous migration; CREATE OR REPLACE on the function is enough.
-- Re-attach just in case it was dropped.
DROP TRIGGER IF EXISTS on_order_delivered_settlements ON public.orders;
CREATE TRIGGER on_order_delivered_settlements
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.generate_settlements_on_delivery();
