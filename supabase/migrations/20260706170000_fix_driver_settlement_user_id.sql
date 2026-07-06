-- ============================================================================
-- CMANDILI -- Fix driver_id/user_id mismatch in generate_settlements_on_delivery (P0)
--
-- Discovered while investigating the loyalty program feature (Phase 1
-- investigation): generate_settlements_on_delivery() inserts NEW.driver_id
-- directly as settlements.user_id:
--
--     INSERT INTO public.settlements (user_id, entity_type, ...)
--     VALUES (NEW.driver_id, 'driver', ...)
--
-- But orders.driver_id stores drivers.id (verified live: 5/5 orders with a
-- driver match drivers.id, 0 match drivers.user_id -- consistent with the
-- documented fact "drivers: id != auth.uid(); user_id = auth.uid()"), while
-- settlements.user_id has FOREIGN KEY REFERENCES auth.users(id). Since
-- drivers.id is never present in auth.users, this INSERT always raises
-- 23503 foreign_key_violation, which ABORTS THE ENTIRE status->'delivered'
-- transition for every non-self-delivery CASH order with a driver assigned
-- -- including the earlier platform_fee/driver_fee_cut stamp in the SAME
-- function, and the original client UPDATE (driver tapping "Confirm
-- Delivery" in cmandili_driver's order_tracking_screen.dart, which has no
-- try/catch around this call).
--
-- Live proof (rolled-back DO $$ block re-running the delivered transition
-- on a real production order):
--   ERROR: 23503: insert or update on table "settlements" violates foreign
--   key constraint "settlements_user_id_fkey"
--   DETAIL: Key (user_id)=(c0170a7b-...) is not present in table "users".
-- Corroborating evidence: settlements table has 0 rows total, ever; the 2
-- production orders that are delivered+driver_id+cash+non-self-delivery
-- both have driver_fee_cut = 0.000 (they reached 'delivered' via direct
-- seed INSERT, which does not fire this AFTER UPDATE trigger).
--
-- Fix: resolve the driver's auth user_id via drivers.user_id before using
-- it in the settlements INSERT. Byte-identical otherwise -- same rates,
-- same self-delivery handling, same SECURITY DEFINER, same entity_id::text
-- cast fix from 20260703140000. Idempotent -- CREATE OR REPLACE.
--
-- This also unblocks (as a side effect, not a redesign):
--   - admin/app/dashboard/livreurs/page.tsx's per-driver commission-owed
--     view, which sums orders.driver_fee_cut -- was silently always 0.
--   - public.wallets driver balance tracking (on_new_settlement_update_wallet
--     fires on settlements INSERT, which never happened for drivers before).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.generate_settlements_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission     NUMERIC(12,3);
  v_partner_user_id       UUID;
  v_driver_user_id        UUID;
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
    --    original TEXT definition -- never compare uuid = text directly.
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- A2) Resolve driver's auth user_id (orders.driver_id = drivers.id,
    --     NOT auth.users.id -- settlements.user_id FKs to auth.users).
    IF NEW.driver_id IS NOT NULL THEN
      SELECT user_id INTO v_driver_user_id
        FROM public.drivers WHERE id = NEW.driver_id LIMIT 1;
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
    --    sufficient -- but explicit self_delivery check makes intent clear)
    IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery AND v_driver_user_id IS NOT NULL THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_driver_user_id,
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
