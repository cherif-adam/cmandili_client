-- ============================================================================
-- CMANDILI -- Proactive low-balance push warning (2-4 DT window)
--
-- enforce_prepaid_block() already has the exact machinery needed: it's a
-- BEFORE INSERT OR UPDATE trigger on wallets with OLD/NEW balance access,
-- and it already implements a "notify once on crossing" pattern for the
-- fully-blocked case. This adds a parallel, earlier warning -- existing
-- floor/blocked/unblock logic is untouched.
--
-- Crossing detection needs no extra state/column: firing on
-- OLD.balance > 4 AND NEW.balance BETWEEN 2 AND 4 is inherently one-shot --
-- once it fires, OLD.balance on the next row update is already <= 4, so the
-- condition can't re-fire until a top-up pushes the balance back above 4 and
-- it descends into the window again. Guarded to TG_OP = 'UPDATE' only, since
-- OLD doesn't exist on INSERT (first-ever wallet row).
--
-- Sends a REAL push via pg_net -> push-on-order-status (new 'low_balance_
-- warning' mode), not just an in-app notifications-table row -- checked
-- first, and public.notifications has zero triggers, so inserting there
-- alone (as the existing blocked-case branch does) would not actually
-- reach the driver's device.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.enforce_prepaid_block()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_floor        NUMERIC(12,3);
  v_is_driver    BOOLEAN;
  v_is_partner   BOOLEAN;
  v_url          TEXT;
  v_secret       TEXT;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.balance IS DISTINCT FROM OLD.balance THEN

    SELECT COALESCE(
      (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'prepaid_min_balance'),
      0
    ) INTO v_floor;

    SELECT EXISTS(SELECT 1 FROM public.drivers  WHERE user_id = NEW.user_id) INTO v_is_driver;
    SELECT EXISTS(SELECT 1 FROM public.partners WHERE user_id = NEW.user_id) INTO v_is_partner;

    IF v_is_driver OR v_is_partner THEN

      IF NEW.balance <= v_floor THEN
        -- Auto-block on empty balance
        NEW.status         := 'blocked';
        NEW.blocked_reason := 'balance';

        IF v_is_driver THEN
          UPDATE public.drivers SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;
        IF v_is_partner THEN
          UPDATE public.partners SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;

        -- Notify once, on the transition into blocked
        IF TG_OP = 'INSERT' OR OLD.balance > v_floor THEN
          INSERT INTO public.notifications (user_id, title, message, type, data)
          VALUES (
            NEW.user_id,
            'Solde épuisé — compte bloqué',
            'Votre solde prépayé est de ' || NEW.balance || ' TND. Rechargez votre solde pour continuer à recevoir des commandes.',
            'wallet_blocked',
            jsonb_build_object('balance', NEW.balance)
          );
        END IF;

      ELSE
        -- Balance is above the floor: auto-unblock ONLY balance-driven blocks.
        IF NEW.status = 'blocked' AND COALESCE(NEW.blocked_reason, 'balance') = 'balance' THEN
          NEW.status         := 'active';
          NEW.blocked_reason := NULL;

          IF v_is_driver THEN
            UPDATE public.drivers SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;
          IF v_is_partner THEN
            UPDATE public.partners SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;
        END IF;
      END IF;

      -- ── Proactive low-balance warning (2-4 DT), fires once per descent ────
      -- from above 4 DT. See header comment for why no extra state is needed.
      IF TG_OP = 'UPDATE' AND OLD.balance > 4 AND NEW.balance BETWEEN 2 AND 4 THEN
        v_url := COALESCE(
          current_setting('app.edge_function_url', true),
          'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
        );
        v_secret := COALESCE(
          current_setting('app.edge_function_secret', true),
          'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
        );
        PERFORM net.http_post(
          url     := v_url,
          headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || v_secret
          ),
          body    := jsonb_build_object(
            'event',   'low_balance_warning',
            'user_id', NEW.user_id,
            'balance', NEW.balance
          )
        );
      END IF;

    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
