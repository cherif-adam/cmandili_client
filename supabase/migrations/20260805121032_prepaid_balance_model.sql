-- ============================================================================
-- Migration: Prepaid Balance (Top-Up) Commission Model
--
-- Flips the platform from a POST-PAID / owe model to a PREPAID model:
--
--   Before: restaurants/drivers started at 0 and went NEGATIVE as they owed
--           the platform its commission; a driver was auto-blocked only at
--           -50 TND.
--
--   After:  the owner manually LOADS balance (a positive `manual_topup`
--           settlement) onto each restaurant/driver. Every delivered cash
--           order DEDUCTS only the platform's commission from that prepaid
--           balance:
--             - restaurant: subtotal * default_restaurant_commission_rate (10%)
--             - driver:     delivery_fee * default_driver_commission_rate (23%)
--           When the balance reaches the floor (`prepaid_min_balance`, default
--           0), the account is BLOCKED (drivers.is_blocked / partners.is_blocked)
--           and stops receiving new orders until the owner tops it up again.
--
-- Reuses the existing wallets + settlements infrastructure:
--   * a top-up  = a POSITIVE settlement (type 'manual_topup')
--   * a commission = a NEGATIVE settlement (type 'commission_deduction')
--   * update_wallet_balance() (AFTER INSERT on settlements) already moves the
--     balance; enforce_prepaid_block() (BEFORE I/U on wallets) enforces blocks.
-- ============================================================================


-- ── 0. wallets table + balance trigger (self-contained) ─────────────────────
--    The wallets system (originally in 20260512_wallets_and_balances.sql) was
--    never applied to the live DB, so create it here idempotently. A settlement
--    INSERT adjusts the matching wallet's balance by settlement.amount.
CREATE TABLE IF NOT EXISTS public.wallets (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  balance        NUMERIC(12,3) NOT NULL DEFAULT 0.000,
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
  updated_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_wallets_user   ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_status ON public.wallets(status);

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
CREATE POLICY "wallets_select_own" ON public.wallets
  FOR SELECT USING (auth.uid() = user_id);

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


-- ── 1. settlements: allow the 'manual_topup' type ───────────────────────────
--    (existing CHECK only allowed order_earning / commission_deduction /
--     payout / collection)
ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_type_check;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_type_check
  CHECK (type IN ('order_earning', 'commission_deduction', 'payout', 'collection', 'manual_topup'));


-- ── 2. wallets: track WHY an account is blocked ─────────────────────────────
--    'balance' = auto-blocked because prepaid balance hit the floor
--    'manual'  = blocked by an admin via /api/block
--    A balance top-up only auto-unblocks accounts blocked for 'balance'.
ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS blocked_reason TEXT
    CHECK (blocked_reason IN ('balance', 'manual'));


-- ── 3. Configurable block floor ─────────────────────────────────────────────
INSERT INTO public.global_settings (setting_key, setting_value, description)
VALUES ('prepaid_min_balance', '0',
        'Prepaid balance floor. When a restaurant/driver wallet balance drops to or below this, the account is auto-blocked until topped up.')
ON CONFLICT (setting_key) DO NOTHING;


-- ── 4. Delivery trigger: deduct COMMISSION ONLY from the prepaid balances ───
--    Built on 20260706170000 (keeps the entity_id::text cast, the
--    drivers.user_id resolution, and the self_delivery handling). The only
--    behavioural change is that BOTH settlements are now negative and equal to
--    the platform's commission (not the net cash owed).
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

    -- Live rates from global_settings (fall back to defaults if rows missing)
    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_restaurant_commission_rate'),
        0.10
    ) INTO v_restaurant_rate;

    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_driver_commission_rate'),
        0.23
    ) INTO v_driver_rate;

    -- Resolve partner user_id (entity_id::text works for uuid or text column)
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- Resolve driver's auth user_id (orders.driver_id = drivers.id, and
    -- settlements.user_id FKs to auth.users)
    IF NEW.driver_id IS NOT NULL THEN
      SELECT user_id INTO v_driver_user_id
        FROM public.drivers WHERE id = NEW.driver_id LIMIT 1;
    END IF;

    -- Commission cuts
    v_restaurant_commission := NEW.subtotal * v_restaurant_rate;
    IF NEW.self_delivery THEN
      v_driver_commission := 0;
    ELSE
      v_driver_commission := NEW.delivery_fee * v_driver_rate;
    END IF;

    -- Stamp the order with the platform's cuts (non-retroactive)
    UPDATE public.orders
       SET platform_fee   = v_restaurant_commission,
           driver_fee_cut = v_driver_commission
     WHERE id = NEW.id;

    -- Partner: deduct the 10% commission from the restaurant's prepaid balance.
    -- (The partner still receives the food cash directly via the driver; the
    --  wallet only tracks the commission the platform takes.)
    IF v_partner_user_id IS NOT NULL AND v_restaurant_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_partner_user_id,
        'restaurant',
        -v_restaurant_commission,
        'commission_deduction',
        'Commission commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
      );
    END IF;

    -- Driver: deduct the delivery-fee commission from the driver's prepaid
    -- balance (driver keeps the delivery cash; platform takes its cut here).
    IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery
       AND v_driver_user_id IS NOT NULL AND v_driver_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_driver_user_id,
        'driver',
        -v_driver_commission,
        'commission_deduction',
        'Commission livraison #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
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


-- ── 5. Prepaid block enforcement (replaces check_driver_wallet_limits) ──────
--    Applies to BOTH drivers and partners. On any wallet balance change:
--      * balance <= floor  -> status='blocked', blocked_reason='balance',
--                             set drivers.is_blocked / partners.is_blocked
--      * balance >  floor   -> if it was blocked for 'balance', auto-unblock
--                             (a 'manual' admin block is left untouched)
CREATE OR REPLACE FUNCTION public.enforce_prepaid_block()
RETURNS TRIGGER AS $$
DECLARE
  v_floor        NUMERIC(12,3);
  v_is_driver    BOOLEAN;
  v_is_partner   BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.balance IS DISTINCT FROM OLD.balance THEN

    SELECT COALESCE(
      (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'prepaid_min_balance'),
      0
    ) INTO v_floor;

    SELECT EXISTS(SELECT 1 FROM public.drivers  WHERE user_id = NEW.user_id) INTO v_is_driver;
    SELECT EXISTS(SELECT 1 FROM public.partners WHERE user_id = NEW.user_id) INTO v_is_partner;

    IF v_is_driver OR v_is_partner THEN

      IF NEW.balance <= v_floor THEN
        -- Auto-block on empty balance
        NEW.status         := 'blocked';
        NEW.blocked_reason := 'balance';

        IF v_is_driver THEN
          UPDATE public.drivers SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;
        IF v_is_partner THEN
          UPDATE public.partners SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;

        -- Notify once, on the transition into blocked
        IF TG_OP = 'INSERT' OR OLD.balance > v_floor THEN
          INSERT INTO public.notifications (user_id, title, message, type, data)
          VALUES (
            NEW.user_id,
            'Solde épuisé — compte bloqué',
            'Votre solde prépayé est de ' || NEW.balance || ' TND. Rechargez votre solde pour continuer à recevoir des commandes.',
            'wallet_blocked',
            jsonb_build_object('balance', NEW.balance)
          );
        END IF;

      ELSE
        -- Balance is above the floor: auto-unblock ONLY balance-driven blocks.
        IF NEW.status = 'blocked' AND COALESCE(NEW.blocked_reason, 'balance') = 'balance' THEN
          NEW.status         := 'active';
          NEW.blocked_reason := NULL;

          IF v_is_driver THEN
            UPDATE public.drivers SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;
          IF v_is_partner THEN
            UPDATE public.partners SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;
        END IF;
      END IF;

    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Retire the old -50 TND driver-only rule and attach the new one.
DROP TRIGGER IF EXISTS driver_wallet_limits_trigger ON public.wallets;
DROP TRIGGER IF EXISTS enforce_prepaid_block_trigger ON public.wallets;
CREATE TRIGGER enforce_prepaid_block_trigger
BEFORE INSERT OR UPDATE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION public.enforce_prepaid_block();


-- ── 6. Grants for the admin top-up flow (service_role) ──────────────────────
GRANT INSERT ON public.settlements TO service_role;
GRANT UPDATE (is_blocked) ON public.drivers  TO service_role;
GRANT UPDATE (is_blocked) ON public.partners TO service_role;


-- ── 7. Clean cutover: give EVERY driver/partner a zero, blocked wallet ──────
--    Prepaid starts clean at 0 for everyone, and — crucially — every existing
--    driver/partner gets a wallet row so the prepaid gate applies from day one
--    (a driver/partner with NO wallet row would otherwise never be blocked).
--    Wipes any legacy owe/negative balances. Customers are unaffected (they
--    have no driver/partner row). Accounts stay blocked until topped up.
--
--    Done with a direct write to is_blocked + a wallet upsert. We set the
--    wallet columns explicitly rather than relying on the trigger so the
--    intent is unambiguous even though enforce_prepaid_block would agree.

-- 7a. Ensure a wallet row exists for every driver and partner.
INSERT INTO public.wallets (user_id, balance, status, blocked_reason)
SELECT d.user_id, 0, 'blocked', 'balance' FROM public.drivers d
UNION
SELECT p.user_id, 0, 'blocked', 'balance' FROM public.partners p
ON CONFLICT (user_id) DO UPDATE
   SET balance        = 0,
       status         = 'blocked',
       blocked_reason = 'balance',
       updated_at     = now();

-- 7b. Reflect the reset onto the gate columns used by dispatch / visibility.
UPDATE public.drivers  SET is_blocked = TRUE;
UPDATE public.partners SET is_blocked = TRUE;
