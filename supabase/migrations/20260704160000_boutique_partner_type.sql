-- ============================================================================
-- CMANDILI — F19: Boutique partner type (additive) + store_type marker
--
-- Context: the partner app gains two signup options. 'Pâtisserie' needs NO
-- schema change (it onboards as a restaurant created with
-- categories=['Pâtisseries'] — the canonical F18 value). 'Boutique' is a real
-- new partners.partner_type whose venue row lives in supermarkets (identical
-- catalog/product data model — grocery_items etc.), so it reuses the whole
-- supermarket pipeline: order_type 'supermarket', waterfall dispatch,
-- settlements, ghost auto-confirm.
--
-- Verified type-agnostic and deliberately UNTOUCHED: the dispatch waterfall
-- (20260510/20260605 — venue joins resolve pickup coords only), the
-- settlements trigger (resolves partner by entity_id, no type filter), ghost
-- auto-confirm triggers, venue/product RLS (a full pg_policies scan found
-- partner_type only in the orders policies), and orders INSERT policies.
-- The legacy "Partners can read their own entity orders" SELECT policy is
-- left as-is: permissive policies OR together, so extending
-- orders_partner_select alone grants boutique visibility.
--
-- Every change below is a strict superset — it only widens an allowlist
-- ('boutique' added next to 'supermarket') — so existing restaurant /
-- supermarket behavior cannot regress.
--
--   1. partners.partner_type CHECK gains 'boutique'.
--   2. supermarkets.store_type marker ('supermarket' default | 'boutique') —
--      browse-surface badge for the customer app + admin; partners RLS is
--      owner-only, so client apps cannot read partner_type, and ghost
--      boutiques have no partner row at all.
--   3. orders_partner_select / orders_partner_update: the supermarket_id
--      branch accepts partner_type 'boutique' (ALTER POLICY).
--   4. guard_orders_column_scope(): same one-list widening in the partner
--      hat (CREATE OR REPLACE, byte-identical otherwise — F17b style).
--
-- PG15-safe + idempotent (DO $$ guards; ALTER POLICY / CREATE OR REPLACE are
-- naturally re-runnable).
-- ============================================================================


-- ── 1. partners.partner_type CHECK: allow 'boutique' ────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.partners'::regclass
      AND conname = 'partners_partner_type_check'
      AND pg_get_constraintdef(oid) ILIKE '%boutique%'
  ) THEN
    ALTER TABLE public.partners
      DROP CONSTRAINT IF EXISTS partners_partner_type_check;
    ALTER TABLE public.partners
      ADD CONSTRAINT partners_partner_type_check
      CHECK (partner_type = ANY (ARRAY['restaurant'::text, 'supermarket'::text, 'boutique'::text]));
  END IF;
END $$;


-- ── 2. supermarkets.store_type marker column ────────────────────────────────

ALTER TABLE public.supermarkets
  ADD COLUMN IF NOT EXISTS store_type TEXT NOT NULL DEFAULT 'supermarket';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.supermarkets'::regclass
      AND conname = 'supermarkets_store_type_check'
  ) THEN
    ALTER TABLE public.supermarkets
      ADD CONSTRAINT supermarkets_store_type_check
      CHECK (store_type = ANY (ARRAY['supermarket'::text, 'boutique'::text]));
  END IF;
END $$;

COMMENT ON COLUMN public.supermarkets.store_type IS
  'supermarket (default) | boutique — browse-surface marker only; boutiques reuse the full supermarket data model and pipeline.';


-- ── 3. Orders RLS: boutique partners ride the supermarket_id branch ─────────
-- Same expressions as the live policies with ONLY the supermarket-branch
-- partner_type list widened. orders_partner_select compares entity_id (UUID)
-- directly; orders_partner_update keeps F14's text→uuid cast form.

ALTER POLICY "orders_partner_select" ON public.orders
  USING (
    restaurant_id IN (
      SELECT entity_id FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type = 'restaurant'
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
    OR supermarket_id IN (
      SELECT entity_id FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type IN ('supermarket', 'boutique')
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
  );

ALTER POLICY "orders_partner_update" ON public.orders
  USING (
    restaurant_id IN (
      SELECT entity_id::text::uuid FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type = 'restaurant'
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
    OR supermarket_id IN (
      SELECT entity_id::text::uuid FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type IN ('supermarket', 'boutique')
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT entity_id::text::uuid FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type = 'restaurant'
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
    OR supermarket_id IN (
      SELECT entity_id::text::uuid FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type IN ('supermarket', 'boutique')
        AND entity_id::text ~ '^[0-9a-f-]{36}$'
    )
  );


-- ── 4. Column guard: boutique partners get the partner hat ──────────────────
-- Byte-identical redefinition of 20260703130000's function with ONLY the
-- supermarket-branch partner_type list widened. The aa_ trigger attachment is
-- untouched (already live); SECURITY INVOKER stays — do not change.

CREATE OR REPLACE FUNCTION public.guard_orders_column_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_uid        uuid;
  v_changed    text[];
  v_allowed    text[] := ARRAY[]::text[];
  v_violations text[];
BEGIN
  -- Server-side paths run as postgres / service_role → untouched.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  v_uid := auth.uid();

  -- Admins are unrestricted (own-profile read is allowed by profiles RLS).
  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_uid AND is_admin = TRUE
  ) THEN
    RETURN NEW;
  END IF;

  -- Diff OLD vs NEW. jsonb comparison is type-safe for every column kind
  -- used on orders (numerics, timestamps, uuids, arrays, jsonb, bools).
  SELECT array_agg(o.key) INTO v_changed
  FROM jsonb_each(to_jsonb(OLD)) o
  JOIN jsonb_each(to_jsonb(NEW)) n USING (key)
  WHERE o.value IS DISTINCT FROM n.value;

  IF v_changed IS NULL THEN
    RETURN NEW; -- value-identical update
  END IF;

  -- Union of allowed columns across the hats this user wears on THIS row.
  IF v_uid IS NOT NULL AND OLD.user_id = v_uid THEN
    v_allowed := v_allowed
      || ARRAY['status', 'cancellation_reason', 'cancelled_by', 'cancelled_at'];
  END IF;

  IF v_uid IS NOT NULL AND (
       (OLD.restaurant_id IS NOT NULL AND OLD.restaurant_id IN (
          SELECT entity_id::text::uuid FROM public.partners
          WHERE user_id = v_uid AND partner_type = 'restaurant'
            AND entity_id::text ~ '^[0-9a-f-]{36}$'))
    OR (OLD.supermarket_id IS NOT NULL AND OLD.supermarket_id IN (
          SELECT entity_id::text::uuid FROM public.partners
          WHERE user_id = v_uid AND partner_type IN ('supermarket', 'boutique')
            AND entity_id::text ~ '^[0-9a-f-]{36}$'))
  ) THEN
    v_allowed := v_allowed || ARRAY['status', 'self_delivery'];
  END IF;

  IF v_uid IS NOT NULL AND OLD.driver_id IS NOT NULL AND OLD.driver_id IN (
    SELECT id FROM public.drivers WHERE user_id = v_uid
  ) THEN
    v_allowed := v_allowed || ARRAY['status', 'bill_receipt_url'];
  END IF;

  -- Atomic claim: driver_id NULL → the caller's own drivers.id (the RLS
  -- WITH CHECK already pins the target id; here we just allow the column).
  IF v_uid IS NOT NULL AND OLD.driver_id IS NULL AND NEW.driver_id IS NOT NULL
     AND NEW.driver_id IN (SELECT id FROM public.drivers WHERE user_id = v_uid)
  THEN
    v_allowed := v_allowed || ARRAY['driver_id'];
  END IF;

  SELECT array_agg(c) INTO v_violations
  FROM unnest(v_changed) c
  WHERE c <> ALL (v_allowed);

  IF v_violations IS NOT NULL THEN
    RAISE EXCEPTION 'ORDER_COLUMN_SCOPE: column(s) % not allowed for this role',
      v_violations
      USING HINT = 'Client apps may only modify the order columns scoped to their role.';
  END IF;

  RETURN NEW;
END;
$$;
