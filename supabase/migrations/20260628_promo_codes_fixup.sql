-- ============================================================================
-- Migration: Promo Codes Fixup
-- Purpose: The promo_codes table already existed with a different schema
--          (type / value / expires_at) vs what 20260628_promo_codes.sql
--          expected (discount_type / discount_value / valid_until).
--          This migration brings the live table to the shape the code uses:
--            - adds max_uses_per_customer (missing)
--            - adds valid_from (missing)
--          Column renames are NOT done to preserve existing data;
--          the admin code + RPC use the actual live column names.
-- ============================================================================

ALTER TABLE public.promo_codes
  ADD COLUMN IF NOT EXISTS max_uses_per_customer INTEGER,
  ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ;

-- Ensure grants are in place (safe to re-run)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.promo_codes TO service_role;
GRANT SELECT, INSERT ON public.user_promo_usages TO service_role;
GRANT SELECT ON public.user_promo_usages TO authenticated;

-- Recreate the RPC using the actual live column names:
--   type          (not discount_type)
--   value         (not discount_value)
--   expires_at    (not valid_until)
--   valid_from    (now added above)
--   max_uses_per_customer (now added above)
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

  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'INACTIVE',
      'error_message', 'Ce code promo n''est plus actif',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  IF v_promo.valid_from IS NOT NULL AND now() < v_promo.valid_from THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code n''est pas encore valable',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  IF v_promo.expires_at IS NOT NULL AND now() > v_promo.expires_at THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code a expiré',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MAX_USES_REACHED',
      'error_message', 'Ce code n''est plus disponible',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

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

  IF v_promo.min_order_amount IS NOT NULL AND p_subtotal < v_promo.min_order_amount THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MIN_ORDER',
      'error_message', 'Montant minimum de ' || v_promo.min_order_amount || ' TND requis pour ce code',
      'discount_amount', 0, 'new_subtotal', NULL
    );
  END IF;

  -- type = 'percentage' or 'fixed_amount'
  IF v_promo.type = 'percentage' THEN
    v_discount := ROUND(p_subtotal * (v_promo.value / 100.0), 3);
  ELSE
    v_discount := LEAST(v_promo.value, p_subtotal);
  END IF;
  v_new_sub := GREATEST(p_subtotal - v_discount, 0);

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

GRANT EXECUTE ON FUNCTION public.apply_promo_code(UUID, TEXT, NUMERIC, BOOLEAN)
  TO authenticated;
