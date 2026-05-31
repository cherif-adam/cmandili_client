-- ============================================================================
-- Migration: Admin Commissions and Settlements
-- Purpose: Support multi-party commission tracking and TND 3-decimal precision
-- ============================================================================

-- ── 1. Global Settings ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.global_settings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key   TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  description   TEXT,
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- Insert default values
INSERT INTO public.global_settings (setting_key, setting_value, description)
VALUES 
  ('rush_hour_multiplier', '1.0', 'Multiplier for delivery fees during rush hour'),
  ('default_restaurant_commission_rate', '0.15', 'Default platform fee percentage for restaurants (15%)'),
  ('default_supermarket_commission_rate', '0.10', 'Default platform fee percentage for supermarkets (10%)'),
  ('default_driver_commission_rate', '0.20', 'Default platform fee percentage taken from driver delivery fee (20%)')
ON CONFLICT (setting_key) DO NOTHING;

ALTER TABLE public.global_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "global_settings_select" ON public.global_settings;
CREATE POLICY "global_settings_select" ON public.global_settings FOR SELECT USING (true);


-- ── 2. Update Partners Table ────────────────────────────────────────────────
-- Add commission_rate to allow per-partner overrides of the global default
ALTER TABLE public.partners 
ADD COLUMN IF NOT EXISTS commission_rate NUMERIC(5,2);


-- ── 3. Update Orders Table (TND Precision & Commissions) ────────────────────
-- We must drop the view first because it depends on the columns we are altering.
DROP VIEW IF EXISTS public.orders_with_customer;

-- Change existing monetary columns to use 3-decimal precision for TND (millimes)
ALTER TABLE public.orders 
ALTER COLUMN subtotal TYPE NUMERIC(12,3),
ALTER COLUMN delivery_fee TYPE NUMERIC(12,3),
ALTER COLUMN total TYPE NUMERIC(12,3);

-- Add new columns for tracking platform cuts
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(12,3) DEFAULT 0,
ADD COLUMN IF NOT EXISTS driver_fee_cut NUMERIC(12,3) DEFAULT 0;

-- Re-create the view now that the underlying columns are updated
CREATE OR REPLACE VIEW public.orders_with_customer AS
SELECT
  o.*,
  COALESCE(
    o.recipient_name,
    p.full_name,
    (SELECT raw_user_meta_data->>'name' FROM auth.users WHERE id = o.user_id),
    'Customer'
  ) AS customer_name,
  COALESCE(
    o.recipient_phone,
    p.phone,
    'No phone provided'
  ) AS customer_phone
FROM public.orders o
LEFT JOIN public.profiles p ON p.id = o.user_id;

GRANT SELECT ON public.orders_with_customer TO anon, authenticated;


-- ── 4. Settlements Table ────────────────────────────────────────────────────
-- Tracks all financial transactions (dues and payouts) between platform and partners/drivers
CREATE TABLE IF NOT EXISTS public.settlements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type      TEXT NOT NULL CHECK (entity_type IN ('restaurant', 'supermarket', 'driver')),
  amount           NUMERIC(12,3) NOT NULL, -- Positive: platform owes user. Negative: user owes platform.
  type             TEXT NOT NULL CHECK (type IN ('order_earning', 'commission_deduction', 'payout', 'collection')),
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed')),
  description      TEXT,
  related_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT now(),
  paid_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_settlements_user ON public.settlements(user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_status ON public.settlements(status);

ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "settlements_select_own" ON public.settlements;
CREATE POLICY "settlements_select_own" ON public.settlements 
FOR SELECT USING (auth.uid() = user_id);

-- Admin policies (using service_role or specific admin role logic later) can bypass RLS or be added as needed.
