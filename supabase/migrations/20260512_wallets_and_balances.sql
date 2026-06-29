-- ============================================================================
-- Migration: Wallets & Balances System
-- Purpose: Implement Phase 1 of the new business logic (Wallets, limits, blocks)
-- ============================================================================

-- 1. Create Wallets Table
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  balance NUMERIC(12,3) NOT NULL DEFAULT 0.000, -- Negative = user owes platform
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_wallets_user ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_status ON public.wallets(status);

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
CREATE POLICY "wallets_select_own" ON public.wallets 
FOR SELECT USING (auth.uid() = user_id);

-- 2. Trigger to update wallet balance on new settlement
CREATE OR REPLACE FUNCTION public.update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.user_id, NEW.amount)
  ON CONFLICT (user_id)
  DO UPDATE SET balance = public.wallets.balance + NEW.amount, updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_settlement_update_wallet ON public.settlements;
CREATE TRIGGER on_new_settlement_update_wallet
AFTER INSERT ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.update_wallet_balance();

-- 3. Trigger for driver wallet limits (-40 TND warning, -50 TND block)
CREATE OR REPLACE FUNCTION public.check_driver_wallet_limits()
RETURNS TRIGGER AS $$
DECLARE
  v_is_driver BOOLEAN;
BEGIN
  -- Only apply logic if balance changed or it's a new wallet
  IF TG_OP = 'INSERT' OR NEW.balance != OLD.balance THEN
    
    -- Check if user is a driver
    SELECT EXISTS(SELECT 1 FROM public.drivers WHERE user_id = NEW.user_id) INTO v_is_driver;

    IF v_is_driver THEN
      -- Hard block logic
      IF NEW.balance <= -50.000 THEN
        NEW.status := 'blocked';
      ELSIF NEW.balance > -50.000 THEN
        NEW.status := 'active';
      END IF;

      -- Warning logic: if balance drops below or equals -40.000 but was above it
      IF NEW.balance <= -40.000 AND (TG_OP = 'INSERT' OR OLD.balance > -40.000) THEN
        INSERT INTO public.notifications (user_id, title, message, type, data)
        VALUES (
          NEW.user_id,
          'Attention : Solde Négatif',
          'Votre solde est de ' || NEW.balance || ' TND. Veuillez régler votre solde pour éviter un blocage automatique à -50 TND.',
          'wallet_warning',
          jsonb_build_object('balance', NEW.balance)
        );
      END IF;

      -- Block logic notification: if crossing the -50.000 threshold
      IF NEW.balance <= -50.000 AND (TG_OP = 'INSERT' OR OLD.balance > -50.000) THEN
        INSERT INTO public.notifications (user_id, title, message, type, data)
        VALUES (
          NEW.user_id,
          'Compte Bloqué',
          'Votre compte a été suspendu car votre solde est de ' || NEW.balance || ' TND. Veuillez payer vos commissions pour recevoir de nouvelles commandes.',
          'wallet_blocked',
          jsonb_build_object('balance', NEW.balance)
        );
      END IF;
      
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS driver_wallet_limits_trigger ON public.wallets;
CREATE TRIGGER driver_wallet_limits_trigger
BEFORE INSERT OR UPDATE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION public.check_driver_wallet_limits();


-- 4. Update nearby_online_drivers RPC to exclude blocked drivers
CREATE OR REPLACE FUNCTION public.nearby_online_drivers(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS TABLE(user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT
    d.user_id,
    public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  -- Left join with wallets. If no wallet exists, assume 'active'
  LEFT JOIN public.wallets w ON w.user_id = d.user_id
  WHERE d.is_online = true
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND COALESCE(w.status, 'active') = 'active'
    AND public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 50;
$$;


-- 5. Trigger to automatically generate settlements when an order is delivered
CREATE OR REPLACE FUNCTION public.generate_settlements_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission NUMERIC(12,3);
  v_partner_user_id UUID;
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' AND NEW.payment_method = 'cash' THEN
    
    -- In cash orders, the driver collects the full total amount.
    -- This means the platform now needs to collect the platform's cut + the partner's cut from the driver.
    -- Actually, it's simpler: The driver owes the platform the restaurant's money AND the platform's commission.
    -- Or, more cleanly:
    -- 1. Partner owes platform 10% of subtotal.
    -- 2. Driver owes platform 23% of delivery fee.
    -- 3. Since driver holds ALL the cash (Subtotal + Delivery Fee), the driver owes the partner their share (Subtotal - 10%).
    -- To centralize this, the driver pays the PLATFORM (owes Subtotal - 10% + 23% of delivery).
    -- Wait, usually the platform owes the restaurant (Subtotal - 10%). So the platform balances it.
    
    -- A) Get partner user_id
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id FROM public.partners WHERE entity_id = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id FROM public.partners WHERE entity_id = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- Calculate cuts (assuming 10% for partner, 23% for driver)
    -- We can read from global_settings or just calculate directly for now since we are setting up the logic
    v_restaurant_commission := NEW.subtotal * 0.10;
    v_driver_commission := NEW.delivery_fee * 0.23;

    -- Update order with calculated fees
    UPDATE public.orders 
    SET platform_fee = v_restaurant_commission, 
        driver_fee_cut = v_driver_commission
    WHERE id = NEW.id;

    -- Create settlements
    
    -- B) Partner settlement: Platform owes Partner (Subtotal - Commission)
    IF v_partner_user_id IS NOT NULL THEN
      INSERT INTO public.settlements (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_partner_user_id, 
        'restaurant', 
        (NEW.subtotal - v_restaurant_commission), -- Positive, platform owes partner
        'order_earning', 
        'Vente commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)), 
        NEW.id,
        'pending'
      );
    END IF;

    -- C) Driver settlement: Driver owes Platform (Partner's share + Driver's commission cut)
    -- Why? Because the driver kept all the cash (Subtotal + Delivery Fee).
    -- So driver owes: (Subtotal - v_restaurant_commission) [which platform owes to partner] + v_driver_commission.
    -- In total, the driver owes: Subtotal - v_restaurant_commission + v_driver_commission
    -- Note: Amount is negative because driver owes platform.
    IF NEW.driver_id IS NOT NULL THEN
      INSERT INTO public.settlements (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        NEW.driver_id, 
        'driver', 
        -((NEW.subtotal - v_restaurant_commission) + v_driver_commission), -- Negative
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

