-- ============================================================================
-- CMANDILI — Make 'delivered' a terminal order status for client-facing roles
--
-- Finding: generate_settlements_on_delivery (20260814090000_loyalty_at_
-- checkout.sql and its predecessors back to 20260512_wallets_and_balances.sql)
-- fires on `NEW.status = 'delivered' AND OLD.status != 'delivered'`. That
-- guard only stops a no-op re-save while already delivered — it does NOT
-- stop an order from being moved OUT of 'delivered' and back IN. The driver
-- RLS UPDATE policy (orders_driver_update_own, 20260703120000) and the
-- column-scope guard (guard_orders_column_scope, 20260703130000) both permit
-- a driver to write `status` on their own order with no transition-graph
-- check — that guard's own header comment says validating transition VALUES
-- is explicitly out of its scope.
--
-- The existing aa_guard_cancelled_terminal (20260707180000) closed this
-- exact class of bug for 'cancelled' but was scoped narrowly to that one
-- status; 'delivered' was left open. A direct API replay —
-- UPDATE orders SET status='onTheWay' ... ; UPDATE orders SET
-- status='delivered' ... a second time — re-fires
-- generate_settlements_on_delivery, inserting a SECOND negative
-- commission_deduction settlement (double-charging the restaurant/driver
-- prepaid wallet) and, for loyalty-milestone orders, a SECOND positive
-- loyalty_subsidy credit. Real double-charge/double-credit vector, entirely
-- independent of any client-side UI guard.
--
-- Fix: same trigger idiom as aa_guard_cancelled_terminal — reject
-- OLD.status='delivered' -> NEW.status<>'delivered' for authenticated/anon,
-- with the same admin + server-role (postgres/service_role) exemptions.
-- Deliberately a SEPARATE trigger (not a merge into
-- aa_guard_cancelled_terminal) so this stays a small, independently
-- reviewable/revertable change.
-- ============================================================================
--
-- ── POUR LE LIVE (29/10/2026) ──────────────────────────────────────────────
-- Jamais appliqué sur le live jusqu'ici. À lancer dans le SQL Editor APRÈS
-- 20261028120000_security_lockdown, puis à enregistrer avec
-- `supabase migration repair --status applied 20260820110000`.
--
-- Ce qui s'est passé sur le live (une notification par changement d'état) :
--   9ff9e204  26/09  delivered → onTheWay 3 s après  → delivered 5 min après
--   3200cf0a  09/10  delivered → onTheWay 7 s après  → delivered 4 s après
--   bfcdb882  11/10  delivered → pickedUp 31 s après → delivered 36 s après
-- onTheWay / pickedUp sont les boutons de l'app livreur, appuyés sur un écran
-- pas encore rafraîchi. Les 3 comptes livreurs ne sont pas admin : cette
-- garde les aurait arrêtés. Aucun chemin serveur ne fait sortir une commande
-- de 'delivered' (cancel_stalled_orders ne touche que pending / confirmed /
-- preparing / ready ; les fonctions colis ne font qu'y entrer ; les Edge
-- Functions ne changent pas le statut).
--
-- Reste permis : tout ce qui précède la livraison (inchangé) ; réenregistrer
-- 'delivered' sur une commande livrée (sans effet) ; l'admin et les chemins
-- serveur (postgres, service_role) pour corriger une erreur. Depuis
-- 20261028120000, même une re-livraison ne paie plus deux fois.
--
-- SECURITY INVOKER obligatoire : en DEFINER, current_user vaudrait le
-- propriétaire de la fonction et la garde ne bloquerait plus personne.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.aa_guard_delivered_terminal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- Server-side paths (dispatch waterfall, settlements, admin dashboard via
  -- service_role, pg_cron) run as postgres/service_role → untouched.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  -- Admins are unrestricted (same exemption as guard_orders_column_scope
  -- and aa_guard_cancelled_terminal).
  IF auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE
  ) THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'delivered' AND NEW.status IS DISTINCT FROM 'delivered' THEN
    RAISE EXCEPTION 'Delivered orders cannot change status (order %)', OLD.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS aa_guard_delivered_terminal ON public.orders;
CREATE TRIGGER aa_guard_delivered_terminal
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.aa_guard_delivered_terminal();


-- ── Contrôle : si quelque chose manque, tout le fichier est annulé ─────────
DO $check$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.orders'::regclass
                    AND tgname = 'aa_guard_delivered_terminal' AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'guard_delivered_terminal incomplet : trigger absent ou désactivé';
  END IF;
  IF (SELECT prosecdef FROM pg_proc
       WHERE oid = to_regprocedure('public.aa_guard_delivered_terminal()')) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'guard_delivered_terminal incomplet : la fonction doit être SECURITY INVOKER';
  END IF;
END
$check$;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : trois colonnes à true.
SELECT EXISTS (SELECT 1 FROM pg_trigger
                WHERE tgrelid = 'public.orders'::regclass
                  AND tgname = 'aa_guard_delivered_terminal' AND tgenabled = 'O') AS garde_active,
       (SELECT NOT prosecdef FROM pg_proc
         WHERE oid = to_regprocedure('public.aa_guard_delivered_terminal()')) AS garde_invoker,
       EXISTS (SELECT 1 FROM pg_indexes
                WHERE schemaname = 'public' AND indexname = 'settlements_once_per_order') AS lockdown_applique;
