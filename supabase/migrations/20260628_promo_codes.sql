-- ============================================================================
-- Migration: Promo Codes
-- Purpose: Create promo_codes + user_promo_usages tables and the
--          apply_promo_code RPC called by cmandili_mobile at checkout.
--
-- The Flutter side (PromoRepository) already expects this exact RPC signature
-- and these table names; this migration brings the DB side into existence.
-- ============================================================================

-- ── 1. promo_codes table ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.promo_codes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT NOT NULL,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
  discount_value        NUMERIC(10,3) NOT NULL CHECK (discount_value > 0),
  min_order_amount      NUMERIC(10,3),
  max_uses              INTEGER,
  max_uses_per_customer INTEGER,
  valid_from            TIMESTAMPTZ,
  valid_until           TIMESTAMPTZ,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  used_count            INTEGER NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enforce case-insensitive uniqueness on code
CREATE UNIQUE INDEX IF NOT EXISTS promo_codes_code_upper_idx
  ON public.promo_codes (UPPER(code));

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

-- service_role (admin dashboard) gets full access
GRANT SELECT, INSERT, UPDATE, DELETE ON public.promo_codes TO service_role;

-- Authenticated customers can only read active codes (the RPC also reads them
-- but is SECURITY DEFINER so it bypasses RLS; this SELECT policy lets the
-- mobile app check a code's existence for display purposes if ever needed).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'promo_codes'
      AND policyname = 'promo_codes_select_active'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "promo_codes_select_active"
      ON public.promo_codes FOR SELECT
      TO authenticated
      USING (is_active = TRUE)
    $p$;
  END IF;
END $$;


-- ── 2. user_promo_usages table ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_promo_usages (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id  UUID NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id       UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  used_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_promo_usages_user_promo_idx
  ON public.user_promo_usages (user_id, promo_code_id);

ALTER TABLE public.user_promo_usages ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.user_promo_usages TO service_role;
GRANT SELECT ON public.user_promo_usages TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'user_promo_usages'
      AND policyname = 'user_promo_usages_select_own'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "user_promo_usages_select_own"
      ON public.user_promo_usages FOR SELECT
      TO authenticated
      USING (user_id = auth.uid())
    $p$;
  END IF;
END $$;


-- ── 3. apply_promo_code RPC ──────────────────────────────────────────────────
-- Called by PromoRepository in cmandili_mobile with:
--   p_user_id    uuid
--   p_promo_code text
--   p_subtotal   numeric
--   p_dry_run    boolean  (true = preview only, false = commit usage)
--
-- Returns JSONB: { status, error_code, error_message, discount_amount, new_subtotal }
CREATE OR REPLACE FUNCTION public.apply_promo_code(
  p_user_id    UUID,
  p_promo_code TEXT,
  p_subtotal   NUMERIC,
  p_dry_run    BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promo       public.promo_codes%ROWTYPE;
  v_user_uses   INTEGER;
  v_discount    NUMERIC(12,3);
  v_new_sub     NUMERIC(12,3);
BEGIN

  -- 1. Lookup (case-insensitive, lock row on commit path to avoid races)
  IF p_dry_run THEN
    SELECT * INTO v_promo FROM public.promo_codes
      WHERE UPPER(code) = UPPER(p_promo_code) LIMIT 1;
  ELSE
    SELECT * INTO v_promo FROM public.promo_codes
      WHERE UPPER(code) = UPPER(p_promo_code) LIMIT 1
      FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'NOT_FOUND',
      'error_message', 'Ce code promo n''existe pas',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- 2. Active?
  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'INACTIVE',
      'error_message', 'Ce code promo n''est plus actif',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- 3. Date range
  IF v_promo.valid_from IS NOT NULL AND now() < v_promo.valid_from THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code n''est pas encore valable',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;
  IF v_promo.valid_until IS NOT NULL AND now() > v_promo.valid_until THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code a expiré',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- 4. Global usage cap
  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MAX_USES_REACHED',
      'error_message', 'Ce code n''est plus disponible',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- 5. Per-customer cap
  IF v_promo.max_uses_per_customer IS NOT NULL THEN
    SELECT COUNT(*) INTO v_user_uses
      FROM public.user_promo_usages
      WHERE promo_code_id = v_promo.id AND user_id = p_user_id;

    IF v_user_uses >= v_promo.max_uses_per_customer THEN
      RETURN jsonb_build_object(
        'status', 'error', 'error_code', 'ALREADY_USED',
        'error_message', 'Vous avez déjà utilisé ce code promo',
        'discount_amount', 0, 'new_subtotal', NULL
      );
    END IF;
  END IF;

  -- 6. Minimum order amount
  IF v_promo.min_order_amount IS NOT NULL AND p_subtotal < v_promo.min_order_amount THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MIN_ORDER',
      'error_message', 'Montant minimum de ' || v_promo.min_order_amount || ' TND requis pour ce code',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- 7. Calculate discount
  IF v_promo.discount_type = 'percentage' THEN
    v_discount := ROUND(p_subtotal * (v_promo.discount_value / 100.0), 3);
  ELSE
    -- fixed_amount: cap at subtotal so new_subtotal never goes negative
    v_discount := LEAST(v_promo.discount_value, p_subtotal);
  END IF;
  v_new_sub := GREATEST(p_subtotal - v_discount, 0);

  -- 8. Commit path: record usage + increment counter
  IF NOT p_dry_run THEN
    UPDATE public.promo_codes
       SET used_count = used_count + 1
     WHERE id = v_promo.id;

    INSERT INTO public.user_promo_usages (promo_code_id, user_id)
    VALUES (v_promo.id, p_user_id);
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'error_code', NULL,
    'error_message', NULL,
    'discount_amount', v_discount,
    'new_subtotal', v_new_sub
  );

END;
$$;

-- Grant execute to authenticated (mobile app calls this)
GRANT EXECUTE ON FUNCTION public.apply_promo_code(UUID, TEXT, NUMERIC, BOOLEAN)
  TO authenticated;
