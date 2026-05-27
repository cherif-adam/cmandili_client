-- ============================================================
-- Cmandili — Promo Code System Migration
-- Run once in the Supabase SQL editor (Dashboard → SQL Editor).
-- ============================================================


-- ── 1. promo_codes ────────────────────────────────────────────────────────────
--
-- Stores every coupon/discount code an admin creates.
-- type  : 'percentage' → value is 0–100 (e.g. 20 = 20 %)
--         'fixed'      → value is a DT amount  (e.g. 5 = 5.000 DT)
-- max_uses  NULL  = unlimited
-- expires_at NULL = never expires
--
CREATE TABLE IF NOT EXISTS public.promo_codes (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  code              TEXT        NOT NULL,
  type              TEXT        NOT NULL CHECK (type IN ('percentage', 'fixed')),
  value             NUMERIC(10,3) NOT NULL CHECK (value > 0),
  min_order_amount  NUMERIC(10,3) NOT NULL DEFAULT 0,
  max_uses          INTEGER,
  used_count        INTEGER     NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  expires_at        TIMESTAMPTZ,
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT promo_codes_code_unique UNIQUE (code)
);

COMMENT ON TABLE  public.promo_codes IS 'Admin-managed discount codes.';
COMMENT ON COLUMN public.promo_codes.type  IS '''percentage'' or ''fixed''';
COMMENT ON COLUMN public.promo_codes.value IS 'Percentage (0-100) or fixed DT amount.';


-- ── 2. user_promo_usages ──────────────────────────────────────────────────────
--
-- One row per (user, promo_code) pair — enforces the one-use-per-user rule
-- at the database level. The UNIQUE constraint is the final safety net even
-- if two concurrent requests both pass the application-level check.
--
CREATE TABLE IF NOT EXISTS public.user_promo_usages (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES auth.users(id)       ON DELETE CASCADE,
  promo_code_id  UUID        NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
  used_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT user_promo_usages_unique UNIQUE (user_id, promo_code_id)
);

COMMENT ON TABLE public.user_promo_usages IS 'Tracks which users have consumed which promo codes.';

-- Fast lookup for the per-user check inside the RPC
CREATE INDEX IF NOT EXISTS idx_user_promo_usages_user_id
  ON public.user_promo_usages (user_id);


-- ── 3. Row-Level Security ─────────────────────────────────────────────────────

ALTER TABLE public.promo_codes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_promo_usages ENABLE ROW LEVEL SECURITY;

-- Authenticated users can look up codes (needed for client-side "does this exist?" hints).
-- The RPC function is SECURITY DEFINER so it bypasses RLS for its own reads/writes.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'promo_codes' AND policyname = 'Authenticated can view active promo codes'
  ) THEN
    CREATE POLICY "Authenticated can view active promo codes"
      ON public.promo_codes FOR SELECT
      TO authenticated
      USING (is_active = TRUE);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'user_promo_usages' AND policyname = 'Users can view own promo usages'
  ) THEN
    CREATE POLICY "Users can view own promo usages"
      ON public.user_promo_usages FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- No client-facing INSERT / UPDATE / DELETE policies on either table.
-- All mutations go through the SECURITY DEFINER RPC below.


-- ── 4. apply_promo_code RPC ───────────────────────────────────────────────────
--
-- Single entry point for both dry-run preview (p_dry_run = TRUE) and
-- committed application (p_dry_run = FALSE).
--
-- Dry run  → all validation checks run, discount is calculated, nothing is
--            written to the DB.  Use this when the user taps "Apply" so the
--            UI can show the preview without committing the usage.
--
-- Commit   → same checks run, but now with SELECT … FOR UPDATE so concurrent
--            calls cannot both pass the max_uses check, followed by an
--            INSERT into user_promo_usages and an UPDATE on used_count.
--            Call this exactly once at order-placement time.
--
-- Response shape (JSONB):
--   {
--     "status":          "success" | "error",
--     "error_code":      null | "NOT_FOUND" | "INACTIVE" | "EXPIRED" |
--                        "MAX_USES_REACHED" | "ALREADY_USED" |
--                        "MIN_ORDER" | "INVALID_CODE",
--     "error_message":   null | "<French human-readable string>",
--     "discount_amount": <NUMERIC – 0 on error>,
--     "new_subtotal":    <NUMERIC – null on error>
--   }
--
CREATE OR REPLACE FUNCTION public.apply_promo_code(
  p_user_id    UUID,
  p_promo_code TEXT,
  p_subtotal   NUMERIC,
  p_dry_run    BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code         TEXT;
  v_promo        public.promo_codes%ROWTYPE;
  v_discount     NUMERIC(10,3);
  v_new_subtotal NUMERIC(10,3);
BEGIN

  -- ── 1. Sanitize: strip whitespace, uppercase, length guard ─────────────
  v_code := UPPER(TRIM(p_promo_code));

  IF v_code = '' OR char_length(v_code) > 50 THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'INVALID_CODE',
      'error_message',   'Code invalide',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 2. Fetch the promo code row ─────────────────────────────────────────
  -- On a commit call (p_dry_run = FALSE) we acquire a row-level exclusive
  -- lock so that two simultaneous checkout requests cannot both observe
  -- used_count < max_uses and both proceed past the check.
  --
  -- On a dry-run preview we do a plain SELECT — no lock needed because we
  -- are not writing anything.
  IF p_dry_run THEN
    SELECT * INTO v_promo
    FROM public.promo_codes
    WHERE code = v_code;
  ELSE
    SELECT * INTO v_promo
    FROM public.promo_codes
    WHERE code = v_code
    FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'NOT_FOUND',
      'error_message',   'Ce code promo n''existe pas',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 3. Active check ─────────────────────────────────────────────────────
  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'INACTIVE',
      'error_message',   'Ce code promo n''est plus actif',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 4. Expiry check ─────────────────────────────────────────────────────
  IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < NOW() THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'EXPIRED',
      'error_message',   'Ce code a expiré',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 5. Max-uses check ───────────────────────────────────────────────────
  -- For the dry run this is an optimistic read; the real serialisation
  -- happens via the row lock on the actual commit call.
  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'MAX_USES_REACHED',
      'error_message',   'Ce code promo a atteint son nombre maximum d''utilisations',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 6. Per-user usage check ─────────────────────────────────────────────
  IF EXISTS (
    SELECT 1
    FROM public.user_promo_usages
    WHERE user_id = p_user_id
      AND promo_code_id = v_promo.id
  ) THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'ALREADY_USED',
      'error_message',   'Vous avez déjà utilisé ce code promo',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 7. Minimum order amount check ───────────────────────────────────────
  IF p_subtotal < v_promo.min_order_amount THEN
    RETURN jsonb_build_object(
      'status',          'error',
      'error_code',      'MIN_ORDER',
      'error_message',   'Montant minimum requis: ' ||
                         to_char(v_promo.min_order_amount, 'FM999990.000') || ' DT',
      'discount_amount', 0,
      'new_subtotal',    NULL
    );
  END IF;

  -- ── 8. Calculate discount ───────────────────────────────────────────────
  -- The discount is applied to the ORDER SUBTOTAL ONLY.
  -- The delivery fee is never reduced by a promo code.
  IF v_promo.type = 'percentage' THEN
    v_discount := ROUND(p_subtotal * (v_promo.value / 100.0), 3);
  ELSE  -- 'fixed'
    v_discount := v_promo.value;
  END IF;

  -- Hard floor: the discounted subtotal can never go below zero.
  -- This guards against a fixed-amount code larger than the subtotal.
  v_new_subtotal := GREATEST(0::NUMERIC, p_subtotal - v_discount);

  -- Recompute actual discount after the floor (matters when fixed > subtotal)
  v_discount := p_subtotal - v_new_subtotal;

  -- ── 9. Commit (skipped on dry run) ──────────────────────────────────────
  IF NOT p_dry_run THEN
    -- Record this user's usage. The UNIQUE constraint on (user_id, promo_code_id)
    -- is the last line of defence: even if a race condition bypasses check 6,
    -- only one INSERT will succeed; the other raises unique_violation which
    -- we catch in the EXCEPTION block below.
    INSERT INTO public.user_promo_usages (user_id, promo_code_id)
    VALUES (p_user_id, v_promo.id);

    -- Increment the global counter. The row is still exclusively locked from
    -- step 2, so this is serialised against all concurrent commit calls.
    UPDATE public.promo_codes
    SET used_count = used_count + 1
    WHERE id = v_promo.id;
  END IF;

  -- ── 10. Return success ───────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'status',          'success',
    'error_code',      NULL,
    'error_message',   NULL,
    'discount_amount', v_discount,
    'new_subtotal',    v_new_subtotal
  );

EXCEPTION WHEN unique_violation THEN
  -- A concurrent commit call already recorded this user's usage between
  -- our EXISTS check and the INSERT.  Treat it as "already used".
  RETURN jsonb_build_object(
    'status',          'error',
    'error_code',      'ALREADY_USED',
    'error_message',   'Vous avez déjà utilisé ce code promo',
    'discount_amount', 0,
    'new_subtotal',    NULL
  );

END;
$$;

-- Allow any authenticated user to call the RPC
GRANT EXECUTE ON FUNCTION public.apply_promo_code(UUID, TEXT, NUMERIC, BOOLEAN)
  TO authenticated;
