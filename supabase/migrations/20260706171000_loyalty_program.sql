-- ============================================================================
-- CMANDILI -- Customer loyalty program (delivery discounts funded by
-- platform, driver payout unaffected)
--
-- Business rules (confirmed):
--   - Lifetime count of DELIVERED orders per customer, unified across
--     food/courier(colis)/facture (all share the same driver-delivery
--     pipeline and the same canonical 8-value orders.status). Supermarket
--     and the dead 'billPayment' order_type are intentionally excluded per
--     product decision.
--   - Cancelled orders never count -- enforced simply by keying off
--     status='delivered' (a cancelled order's status is 'cancelled', never
--     'delivered'; there is no live path that flips cancelled->delivered).
--   - Every 5th counted order (excluding multiples of 10): customer charged
--     50% of that order's real delivery fee.
--   - Every 10th: customer charged 0 delivery fee.
--   - Driver settlement must be COMPLETELY UNCHANGED for milestone orders.
--     generate_settlements_on_delivery() (see 20260706170000) computes
--     driver_fee_cut from NEW.delivery_fee/NEW.subtotal -- this migration
--     NEVER writes to orders.delivery_fee or orders.subtotal, only to two
--     new, guard-blocked, trigger-only columns. The shortfall is tracked as
--     a separate Cmandili->driver payout, never deducted from the driver.
--   - No automatic transfer: milestone orders create a pending
--     loyalty_driver_payouts row for Adam to settle manually.
--
-- Design notes / deviations worth flagging:
--   - The lifetime counter is NOT a column on public.profiles. profiles has
--     an RLS policy "profiles_update" (`USING (auth.uid() = id)`) with NO
--     column-scope guard (unlike orders' aa_guard_orders_column_scope) --
--     any authenticated customer can UPDATE any column of their own
--     profiles row today. Putting the counter there would let a customer
--     forge their own milestone by just setting the value client-side. So
--     it lives in a brand-new table (loyalty_customer_progress) that has
--     RLS enabled with a SELECT-own policy and NO write policy at all for
--     authenticated/anon -- only the SECURITY DEFINER trigger (owned by
--     postgres, which bypasses RLS) can write it. This is additive and
--     does not touch profiles' existing RLS.
--   - orders.loyalty_milestone_type / loyalty_discount_amount are new
--     columns. guard_orders_column_scope (20260703130000) is deny-by-
--     default: since neither column is added to ANY role's allowed array,
--     all 4 client roles are already blocked from writing them with zero
--     changes to that trigger. Confirmed in Phase 1 investigation.
--   - loyalty_driver_payouts.driver_id references public.drivers(id) (NOT
--     auth.users(id)) -- orders.driver_id is a drivers.id, and mixing the
--     two id spaces is exactly the bug fixed in 20260706170000. Storing
--     drivers.id here (same convention as orders.driver_id) avoids
--     repeating that mistake; the admin dashboard already keys drivers by
--     drivers.id (see livreurs/page.tsx grouping by o.driver_id).
--
-- PG15-safe + idempotent (DO $$ pg_policies/pg_trigger guards, no
-- CREATE POLICY IF NOT EXISTS).
-- ============================================================================


-- ── 1. orders: new trigger-only columns ─────────────────────────────────────

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS loyalty_milestone_type   TEXT
    CHECK (loyalty_milestone_type IN ('half', 'free')),
  ADD COLUMN IF NOT EXISTS loyalty_discount_amount   NUMERIC(12,3) NOT NULL DEFAULT 0;


-- ── 2. Customer lifetime progress (one row per customer) ────────────────────

CREATE TABLE IF NOT EXISTS public.loyalty_customer_progress (
  customer_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  delivered_count  INTEGER NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.loyalty_customer_progress ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'loyalty_customer_progress' AND policyname = 'loyalty_customer_progress_select_own'
  ) THEN
    CREATE POLICY "loyalty_customer_progress_select_own" ON public.loyalty_customer_progress
      FOR SELECT USING (auth.uid() = customer_id);
  END IF;
END $$;

-- No INSERT/UPDATE/DELETE policy for authenticated/anon on purpose: only
-- the SECURITY DEFINER trigger function (owned by postgres) writes here.


-- ── 3. Driver payout ledger (admin-visible "pending cases" list) ───────────

CREATE TABLE IF NOT EXISTS public.loyalty_driver_payouts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id       UUID NOT NULL REFERENCES public.orders(id),
  driver_id      UUID NOT NULL REFERENCES public.drivers(id),
  customer_id    UUID NOT NULL REFERENCES auth.users(id),
  milestone_type TEXT NOT NULL CHECK (milestone_type IN ('half', 'free')),
  amount_owed    NUMERIC(12,3) NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'settled')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at     TIMESTAMPTZ,
  settled_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE (order_id)
);

CREATE INDEX IF NOT EXISTS idx_loyalty_payouts_driver ON public.loyalty_driver_payouts(driver_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_payouts_status ON public.loyalty_driver_payouts(status);

ALTER TABLE public.loyalty_driver_payouts ENABLE ROW LEVEL SECURITY;
-- No policies at all: this table is admin-only (dashboard uses
-- supabaseAdmin/service_role, which bypasses RLS) and trigger-written
-- (SECURITY DEFINER, bypasses RLS). Deny-by-default for authenticated/anon.


-- ── 4. Trigger: apply loyalty program on genuine delivery ───────────────────

CREATE OR REPLACE FUNCTION public.apply_loyalty_program()
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
  IF NEW.status = 'delivered' AND OLD.status != 'delivered'
     AND NEW.order_type IN ('food', 'courier', 'facture') THEN

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

    IF v_milestone IS NOT NULL THEN
      -- Customer-facing discount stamp ONLY. delivery_fee/subtotal (the
      -- columns generate_settlements_on_delivery reads to compute
      -- driver_fee_cut) are never touched here.
      UPDATE public.orders
         SET loyalty_milestone_type  = v_milestone,
             loyalty_discount_amount = v_discount
       WHERE id = NEW.id;

      -- Only owe a driver payout if a real driver delivered it (self-
      -- delivery orders have no driver_id and no one to top up).
      IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery THEN
        INSERT INTO public.loyalty_driver_payouts
          (order_id, driver_id, customer_id, milestone_type, amount_owed, status)
        VALUES (NEW.id, NEW.driver_id, NEW.user_id, v_milestone, v_discount, 'pending')
        ON CONFLICT (order_id) DO NOTHING;
      END IF;
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_delivered_loyalty ON public.orders;
CREATE TRIGGER on_order_delivered_loyalty
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.apply_loyalty_program();
