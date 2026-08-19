-- ============================================================================
-- CMANDILI — Roll back a committed promo-code usage on order/payment failure.
--
-- Bug: checkout_screen.dart calls apply_promo_code(p_dry_run=false) BEFORE
-- createOrder(). That commits used_count++ and a user_promo_usages row
-- immediately (20260628_promo_codes_fixup.sql:125-132). If createOrder()
-- then throws (network blip, RLS rejection, venue-closed race) or the
-- subsequent payment step fails, nothing anywhere decrements used_count or
-- deletes the usage row — cancelOrder()/cancelOrderByCustomer() never touch
-- promo_codes/user_promo_usages. A customer using a single-use or
-- globally-capped code permanently burns it with no order and no discount
-- to show for it.
--
-- Fix: a companion RPC the client calls from both failure paths (createOrder
-- catch block, payment-failure branch) to undo exactly the commit that
-- apply_promo_code made. SECURITY DEFINER + p_user_id-scoped delete so a
-- caller can only release their own usage, matching apply_promo_code's own
-- security model. Idempotent: calling it twice, or calling it when there was
-- no usage to release, is a safe no-op (checks rowcount before decrementing).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.release_promo_usage(
  p_user_id    UUID,
  p_promo_code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promo_id UUID;
  v_deleted  INTEGER;
BEGIN
  SELECT id INTO v_promo_id FROM public.promo_codes
    WHERE UPPER(code) = UPPER(p_promo_code) LIMIT 1;

  IF v_promo_id IS NULL THEN
    RETURN; -- Nothing to release.
  END IF;

  -- Only delete the most recent usage row for this (user, code) pair — if
  -- the customer has ever legitimately used this code before (multi-use
  -- codes), we must not remove that earlier, order-backed usage.
  DELETE FROM public.user_promo_usages
  WHERE id = (
    SELECT id FROM public.user_promo_usages
    WHERE promo_code_id = v_promo_id AND user_id = p_user_id
    ORDER BY used_at DESC
    LIMIT 1
  );
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted > 0 THEN
    UPDATE public.promo_codes
       SET used_count = GREATEST(used_count - 1, 0)
     WHERE id = v_promo_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_promo_usage(UUID, TEXT)
  TO authenticated;
