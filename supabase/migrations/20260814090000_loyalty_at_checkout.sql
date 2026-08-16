-- ============================================================================
-- CMANDILI -- Move the loyalty milestone discount from "cosmetic post-
-- delivery stamp" to a real, checkout-time price reduction, with the driver
-- kept whole via an automatic subsidy settlement.
--
-- Supersedes 20260706171000_loyalty_program.sql's apply_loyalty_program()
-- trigger, which only ever stamped loyalty_milestone_type/loyalty_discount_
-- amount AFTER delivery -- delivery_fee/total were never touched, so the
-- customer always paid full price and the post-delivery banner was purely
-- informational. See investigation notes in-thread; this migration is the
-- real implementation.
--
-- What changes:
--   1. Milestone determination moves to a BEFORE INSERT trigger on orders.
--      It now REDUCES NEW.delivery_fee/NEW.total at creation time, before
--      the client ever sees a price or a driver ever sees an offer.
--   2. loyalty_customer_progress.delivered_count now increments at order
--      CREATION (so the milestone is known immediately), not at delivery.
--      A companion AFTER UPDATE trigger releases the slot again if the
--      order is cancelled before delivery, preserving the original design's
--      "cancelled orders never count" rule.
--   3. generate_settlements_on_delivery() gains one more settlement insert:
--      a POSITIVE 'loyalty_subsidy' crediting the driver exactly what the
--      client was NOT charged, net of the driver's own commission rate, so
--      the driver's take-home for a milestone delivery is identical to a
--      full-price one. Math (driver rate r, discount d):
--        collected  = delivery_fee (already reduced by d)
--        commission = collected * r                      (unchanged formula)
--        subsidy    = d * (1 - r)
--        net        = collected - commission + subsidy
--                   = (F-d) - (F-d)*r + d*(1-r) = F*(1-r) = same as normal
--   4. apply_loyalty_program() + its trigger are DROPPED: every job it did
--      is superseded, and leaving it running would double-increment the
--      counter (once here at INSERT, once there at delivery).
--   5. loyalty_driver_payouts stops receiving new rows (the admin dashboard
--      keeps it for reconciling pre-existing pending/settled records).
--
-- PG15-safe + idempotent (DO $$ pg_trigger/pg_policies guards where used).
-- ============================================================================


-- ── 1. settlements: allow the new subsidy type ──────────────────────────────
ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_type_check;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_type_check
  CHECK (type IN ('order_earning', 'commission_deduction', 'payout', 'collection', 'manual_topup', 'loyalty_subsidy'));


-- ── 2. BEFORE INSERT trigger: determine + apply the discount at creation ───
-- SECURITY DEFINER (owned by postgres) so it can write loyalty_customer_
-- progress regardless of the inserting customer's own RLS grants -- same
-- justification as the trigger it replaces. Runs BEFORE INSERT, so
-- guard_orders_column_scope (BEFORE UPDATE only) never even sees this.

CREATE OR REPLACE FUNCTION public.apply_loyalty_at_checkout()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count     INTEGER;
  v_milestone TEXT;
  v_discount  NUMERIC(12,3);
BEGIN
  IF NEW.order_type IN ('food', 'courier', 'facture') THEN

    -- Atomic upsert: Postgres serializes concurrent INSERT..ON CONFLICT DO
    -- UPDATE statements targeting the same customer_id row, so two orders
    -- placed by the same customer at nearly the same instant still get
    -- distinct, correctly-ordered counter values -- no separate explicit
    -- lock needed.
    INSERT INTO public.loyalty_customer_progress (customer_id, delivered_count, updated_at)
    VALUES (NEW.user_id, 1, now())
    ON CONFLICT (customer_id) DO UPDATE
      SET delivered_count = public.loyalty_customer_progress.delivered_count + 1,
          updated_at      = now()
    RETURNING delivered_count INTO v_count;

    IF v_count % 10 = 0 THEN
      v_milestone := 'free';
      v_discount  := NEW.delivery_fee;
    ELSIF v_count % 5 = 0 THEN
      v_milestone := 'half';
      v_discount  := NEW.delivery_fee * 0.5;
    END IF;

    IF v_milestone IS NOT NULL AND v_discount > 0 THEN
      NEW.loyalty_milestone_type  := v_milestone;
      NEW.loyalty_discount_amount := v_discount;
      -- total was computed by the client as (subtotal + delivery_fee) or
      -- equivalent (courier: total=delivery_fee, facture: total=amount+fee)
      -- -- in every case it already includes delivery_fee exactly once, so
      -- subtracting the same discount from both keeps that identity intact
      -- regardless of which order type this is.
      NEW.total        := NEW.total - v_discount;
      NEW.delivery_fee := NEW.delivery_fee - v_discount;
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_insert_loyalty ON public.orders;
CREATE TRIGGER on_order_insert_loyalty
BEFORE INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.apply_loyalty_at_checkout();


-- ── 3. AFTER UPDATE trigger: release the slot if a milestone order never
--      delivers (preserves "cancelled orders never count") ────────────────
-- guard_cancelled_terminal (20260707180000) already blocks cancelled ->
-- delivered, so an order that takes this path can never later reach the
-- subsidy-granting branch of generate_settlements_on_delivery -- no
-- double-handling risk between the two triggers.

CREATE OR REPLACE FUNCTION public.release_loyalty_slot_on_cancel()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled'
     AND OLD.loyalty_milestone_type IS NOT NULL THEN
    UPDATE public.loyalty_customer_progress
       SET delivered_count = GREATEST(delivered_count - 1, 0),
           updated_at      = now()
     WHERE customer_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_cancelled_release_loyalty ON public.orders;
CREATE TRIGGER on_order_cancelled_release_loyalty
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.release_loyalty_slot_on_cancel();


-- ── 4. generate_settlements_on_delivery(): add the driver subsidy ──────────
-- Identical to the 20260805121032 version except for the new block at the
-- end. Commission calculation is untouched -- it naturally computes a
-- smaller commission because NEW.delivery_fee is already the discounted
-- value by the time delivery happens (stamped at INSERT, step 2 above).

CREATE OR REPLACE FUNCTION public.generate_settlements_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission     NUMERIC(12,3);
  v_partner_user_id       UUID;
  v_driver_user_id        UUID;
  v_restaurant_rate       NUMERIC(5,4);
  v_driver_rate           NUMERIC(5,4);
  v_subsidy               NUMERIC(12,3);
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

    -- Driver: loyalty subsidy. NEW.loyalty_discount_amount is what the
    -- client was NOT charged (stamped at order creation). Net of the same
    -- commission rate the driver already paid above, so cash collected -
    -- commission + subsidy == a normal full-price delivery's net earning.
    IF NEW.loyalty_milestone_type IS NOT NULL AND NEW.driver_id IS NOT NULL
       AND NOT NEW.self_delivery AND v_driver_user_id IS NOT NULL THEN
      v_subsidy := NEW.loyalty_discount_amount * (1 - v_driver_rate);
      IF v_subsidy > 0 THEN
        INSERT INTO public.settlements
          (user_id, entity_type, amount, type, description, related_order_id, status)
        VALUES (
          v_driver_user_id,
          'driver',
          v_subsidy,
          'loyalty_subsidy',
          'Subvention fidélité (' ||
            CASE NEW.loyalty_milestone_type WHEN 'free' THEN 'livraison gratuite' ELSE '-50% livraison' END ||
            ') #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
          NEW.id,
          'paid'
        );
      END IF;
    END IF;

  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger already exists (on_order_delivered_settlements) and points at this
-- function by name; CREATE OR REPLACE above is enough, no re-attach needed.


-- ── 5. Retire the old post-delivery trigger ─────────────────────────────────
-- Every job it did is superseded by steps 2-4 above. Must be dropped, not
-- just left inert: if it kept running it would increment
-- loyalty_customer_progress.delivered_count a SECOND time at delivery,
-- double-counting every order.

DROP TRIGGER IF EXISTS on_order_delivered_loyalty ON public.orders;
DROP FUNCTION IF EXISTS public.apply_loyalty_program();

-- loyalty_driver_payouts is intentionally left in place (untouched schema +
-- data): it holds real pending/settled rows from before this migration that
-- still need manual reconciliation. Nothing inserts into it anymore.
