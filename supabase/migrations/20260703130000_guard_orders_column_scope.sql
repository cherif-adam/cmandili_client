-- ============================================================================
-- CMANDILI — Column-scope guard on public.orders (P1 financial integrity,
-- follow-up to the 20260703120000 UPDATE-RLS tightening)
--
-- Problem: RLS WITH CHECK cannot see OLD values, so an actor legitimately
-- scoped to a row (driver on their accepted order, customer on their own
-- order, partner on their venue's order) could still rewrite columns outside
-- their logical scope in the same UPDATE — e.g. a driver editing `total`, a
-- customer zeroing `delivery_fee` while cancelling, a partner reassigning
-- `restaurant_id`.
--
-- Fix: a BEFORE UPDATE trigger that diffs OLD vs NEW and rejects any change
-- to a column outside the caller's allowed list. Deny-by-default: columns
-- added to the table later are guarded automatically.
--
-- Allowed columns per hat (union across all hats the caller wears ON THIS
-- ROW — some real users are e.g. both customer and driver):
--   customer (OLD.user_id = auth.uid())        → status, cancellation_reason,
--                                                 cancelled_by, cancelled_at
--   partner  (OLD venue ∈ their partners rows) → status, self_delivery
--   driver   (OLD.driver_id = their id)        → status, bill_receipt_url
--   driver claim (OLD.driver_id IS NULL →
--                 NEW.driver_id = their id)    → driver_id
--   admin    (profiles.is_admin)               → unrestricted
--
-- Who the guard does NOT touch (early return when current_user is not an
-- end-user API role): every SECURITY DEFINER function owned by postgres
-- (dispatch waterfall, offer_order_to_driver, rotate_expired_offers,
-- pass_order_offer, generate_settlements_on_delivery's fee stamp), pg_cron,
-- and the admin dashboard / edge functions using service_role. The trigger
-- function is SECURITY INVOKER precisely so current_user reflects the real
-- executing role ('postgres' inside definer functions, 'service_role' for
-- the dashboard, 'authenticated' for the apps).
--
-- NOTE on driver_fee_cut for self-delivery: the 0-set is stamped by the
-- SECURITY DEFINER settlements trigger, never by the partner app, so
-- driver_fee_cut is deliberately NOT client-writable.
--
-- Trigger name starts with 'aa_' ON PURPOSE: BEFORE triggers fire in
-- alphabetical order and this guard must run before order_cancelled_at /
-- order_status_timestamps mutate NEW (their stamps would otherwise look
-- like client changes and be rejected).
--
-- What this guard does NOT do: it does not validate status transition
-- VALUES (any allowed role can set any status string the CHECKs accept) —
-- that is a business-rules layer, not column integrity.
--
-- PG15-safe + idempotent: CREATE OR REPLACE FUNCTION + DO $$ pg_trigger
-- guard, same pattern as enforce_venue_open.
-- ============================================================================


-- ── 1. Guard function (SECURITY INVOKER — do not change to DEFINER) ─────────

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
          WHERE user_id = v_uid AND partner_type = 'supermarket'
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


-- ── 2. Attach trigger (idempotent, PG15-safe) ────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'aa_guard_orders_column_scope'
      AND tgrelid = 'public.orders'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER aa_guard_orders_column_scope
      BEFORE UPDATE ON public.orders
      FOR EACH ROW
      EXECUTE FUNCTION public.guard_orders_column_scope();
  END IF;
END $$;
