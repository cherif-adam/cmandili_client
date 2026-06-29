-- ============================================================================
-- Migration: Admin Manual Dispatch
-- Purpose: Admin can force-offer a stuck order to a specific online driver.
--
-- Design decisions:
--   - Uses offer_order_to_driver (same FCM push path as auto-dispatch)
--     so the driver sees the countdown dialog exactly as normal.
--   - Uses a 60-second offer window (vs 10s for auto-dispatch) to give
--     the admin confidence the driver will see it.
--   - Resets passed_driver_ids so the chosen driver can receive the offer
--     even if they previously passed on this order.
--   - If the driver rejects, the normal waterfall resumes from a clean slate.
--   - Only callable via service_role (admin Next.js uses service_role key).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_dispatch_order(
  p_order_id  UUID,
  p_driver_id UUID,
  p_window_seconds INT DEFAULT 60
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
  v_driver_id UUID;
BEGIN
  -- Verify order exists, has no driver yet, and is in a dispatchable state
  SELECT status, driver_id
    INTO v_status, v_driver_id
    FROM public.orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Commande introuvable');
  END IF;

  IF v_driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Cette commande a déjà un livreur assigné');
  END IF;

  IF v_status NOT IN ('pending', 'confirmed', 'ready') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Statut de commande non dispatchable: ' || v_status);
  END IF;

  -- Verify driver exists, is online, not blocked
  IF NOT EXISTS (
    SELECT 1 FROM public.drivers
     WHERE id = p_driver_id AND is_online = TRUE AND is_blocked = FALSE
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Livreur indisponible ou bloqué');
  END IF;

  -- Reset dispatch state: clear any pending offer and start fresh
  UPDATE public.orders
     SET passed_driver_ids    = '{}'::UUID[],
         assigned_driver_id   = NULL,
         assignment_expires_at = NULL
   WHERE id = p_order_id
     AND driver_id IS NULL;

  -- Offer the order with a longer window for admin-initiated dispatch
  PERFORM public.offer_order_to_driver(p_order_id, p_driver_id, p_window_seconds);

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Admin Next.js uses service_role key; no need to expose to authenticated
GRANT EXECUTE ON FUNCTION public.admin_dispatch_order(UUID, UUID, INT) TO service_role;
