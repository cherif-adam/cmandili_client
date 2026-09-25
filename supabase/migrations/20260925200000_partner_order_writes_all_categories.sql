-- ============================================================================
-- CMANDILI -- Laisser TOUTES les categories de partenaire faire avancer leurs
--             commandes (option 1)
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- ── LE PROBLEME, MESURE ────────────────────────────────────────────────────
-- Deux garde-fous codent en dur la liste 'restaurant' / 'supermarket'. Les
-- categories generiques (flowers, pets, bakery, gifts, electronics) n'y
-- figurent pas, donc un fleuriste ne peut PAS accepter une commande -- quel
-- que soit son solde.
--
--   1. la policy RLS `orders_partner_update`
--   2. le trigger BEFORE UPDATE `guard_orders_column_scope`
--
-- Test en transaction annulee, avant ce script :
--   piccolomondo (restaurant, actif) -> 1 ligne(s)
--   fleurs       (flowers)           -> 0 ligne(s)
--   animalerie type=pets         reconnu_par_la_policy = f
--   cadeau     type=gifts        reconnu_par_la_policy = f
--   delice     type=bakery       reconnu_par_la_policy = f
--   digital    type=electronics  reconnu_par_la_policy = f
--   fleurs     type=flowers      reconnu_par_la_policy = f
--   texas      type=restaurant   reconnu_par_la_policy = t
--
-- ── LE PRINCIPE DU CORRECTIF ───────────────────────────────────────────────
-- On ne remplace pas une liste de types par une liste plus longue : toute
-- nouvelle categorie ajoutee dans `vendor_categories` casserait de nouveau le
-- flux. La question posee devient "ce partenaire possede-t-il CETTE boutique",
-- ce qui est vrai pour n'importe quelle categorie, presente ou future.
--
-- Les deux restent lies a auth.uid() et `is_blocked = false` est conserve dans
-- la policy : aucun chemin anonyme, aucun partenaire ne peut toucher aux
-- commandes d'un autre, et un compte bloque pour solde reste bloque.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================


-- ── 1. La policy ───────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies
             WHERE schemaname='public' AND tablename='orders'
               AND policyname='orders_partner_update') THEN
    EXECUTE 'DROP POLICY orders_partner_update ON public.orders';
  END IF;
END
$$;

CREATE POLICY orders_partner_update
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.user_id    = auth.uid()
        AND p.is_blocked = false
        -- entity_id est du texte : on ne caste que ce qui est un uuid, sinon
        -- une ligne malformee ferait echouer la policy entiere.
        AND p.entity_id::text ~ '^[0-9a-f-]{36}$'
        AND (p.entity_id::text::uuid = orders.restaurant_id
          OR p.entity_id::text::uuid = orders.supermarket_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.user_id    = auth.uid()
        AND p.is_blocked = false
        AND p.entity_id::text ~ '^[0-9a-f-]{36}$'
        AND (p.entity_id::text::uuid = orders.restaurant_id
          OR p.entity_id::text::uuid = orders.supermarket_id)
    )
  );


-- ── 2. Le trigger de portee des colonnes ───────────────────────────────────
-- Identique a l'actuel, A UNE BRANCHE PRES : celle du partenaire, qui ne
-- filtre plus par partner_type. Les branches client, livreur et la prise de
-- course sont recopiees telles quelles.
CREATE OR REPLACE FUNCTION public.guard_orders_column_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid        uuid;
  v_changed    text[];
  v_allowed    text[] := ARRAY[]::text[];
  v_violations text[];
BEGIN
  -- Les chemins serveur (postgres / service_role) ne sont pas concernes.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  v_uid := auth.uid();

  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_uid AND is_admin = TRUE
  ) THEN
    RETURN NEW;
  END IF;

  SELECT array_agg(o.key) INTO v_changed
  FROM jsonb_each(to_jsonb(OLD)) o
  JOIN jsonb_each(to_jsonb(NEW)) n USING (key)
  WHERE o.value IS DISTINCT FROM n.value;

  IF v_changed IS NULL THEN
    RETURN NEW;
  END IF;

  -- Client proprietaire de la commande.
  IF v_uid IS NOT NULL AND OLD.user_id = v_uid THEN
    v_allowed := v_allowed
      || ARRAY['status', 'cancellation_reason', 'cancelled_by', 'cancelled_at'];
  END IF;

  -- Partenaire proprietaire de la boutique -- TOUTE categorie.
  -- (Avant : deux branches filtrees sur partner_type = 'restaurant' et
  --  'supermarket', qui excluaient fleurs / animalerie / patisserie /
  --  cadeaux / electronique.)
  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.partners p
    WHERE p.user_id = v_uid
      AND p.entity_id::text ~ '^[0-9a-f-]{36}$'
      AND (p.entity_id::text::uuid = OLD.restaurant_id
        OR p.entity_id::text::uuid = OLD.supermarket_id)
  ) THEN
    v_allowed := v_allowed || ARRAY['status', 'self_delivery'];
  END IF;

  -- Livreur affecte.
  IF v_uid IS NOT NULL AND OLD.driver_id IS NOT NULL AND OLD.driver_id IN (
    SELECT id FROM public.drivers WHERE user_id = v_uid
  ) THEN
    v_allowed := v_allowed || ARRAY['status', 'bill_receipt_url'];
  END IF;

  -- Prise de course atomique.
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


-- ── Verification (apres application) ───────────────────────────────────────
-- Rejouez le meme test qu'avant : les 5 comptes generiques doivent passer de
-- 0 a 1 ligne sur une de LEURS commandes, et rester a 0 sur celle d'un autre.
-- Le passage direct confirmed -> ready n'a besoin d'aucune regle
-- supplementaire : rien en base n'impose l'ordre des statuts (verifie sur
-- orders_status_check, aa_guard_cancelled_terminal, handle_order_status_change,
-- notify_fcm_on_order_status, notify_fcm_fanout_ready_order et
-- handle_order_status_timestamps).
