-- ============================================================================
-- Retour arrière de supabase/migrations/20261104120000_arrondi_50_millimes.sql
--
-- PAS une migration : fichier rangé hors de supabase/migrations, jamais
-- appliqué automatiquement. À lancer dans le SQL Editor (projet cmandili)
-- seulement pour revenir au calcul au millime.
--
-- Les 4 corps ci-dessous sont les définitions LIVE lues le 04/11/2026 avec
-- pg_get_functiondef, AVANT la migration, copiées sans retouche ; seules les
-- fins de ligne Windows (CRLF) du live sont écrites en LF. La vérification
-- finale compare l'empreinte SHA-256 de chaque corps restauré à celle du live.
-- Ne touche à aucune commande, aucun règlement, aucun portefeuille déjà écrits.
-- ============================================================================

-- ── 1. Les 4 fonctions reviennent à leur version d'avant ──────────────────

-- 3a. apply_loyalty_at_checkout (trigger BEFORE INSERT on_order_insert_loyalty)
CREATE OR REPLACE FUNCTION public.apply_loyalty_at_checkout()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_count     INTEGER;
  v_milestone TEXT;
  v_discount  NUMERIC(12,3);
BEGIN
  IF NEW.order_type NOT IN ('supermarket', 'grocery', 'billPayment') THEN

    -- Atomic upsert: Postgres serializes concurrent INSERT..ON CONFLICT DO
    -- UPDATE statements targeting the same customer_id row, so two orders
    -- placed by the same customer at nearly the same instant still get
    -- distinct, correctly-ordered counter values -- no separate explicit
    -- lock needed.
    INSERT INTO public.loyalty_customer_progress (customer_id, delivered_count, updated_at)
    VALUES (NEW.user_id, 1, now())
    ON CONFLICT (customer_id) DO UPDATE
      SET delivered_count = public.loyalty_customer_progress.delivered_count + 1,
          updated_at      = now()
    RETURNING delivered_count INTO v_count;

    IF v_count % 10 = 0 THEN
      v_milestone := 'free';
      v_discount  := NEW.delivery_fee;
    ELSIF v_count % 5 = 0 THEN
      v_milestone := 'half';
      v_discount  := NEW.delivery_fee * 0.5;
    END IF;

    IF v_milestone IS NOT NULL AND v_discount > 0 THEN
      NEW.loyalty_milestone_type  := v_milestone;
      NEW.loyalty_discount_amount := v_discount;
      -- total was computed by the client as (subtotal + delivery_fee) or
      -- equivalent (courier: total=delivery_fee, facture: total=amount+fee)
      -- -- in every case it already includes delivery_fee exactly once, so
      -- subtracting the same discount from both keeps that identity intact
      -- regardless of which order type this is.
      NEW.total        := NEW.total - v_discount;
      NEW.delivery_fee := NEW.delivery_fee - v_discount;
    END IF;

  END IF;
  RETURN NEW;
END;
$function$;

-- 3b. generate_settlements_on_delivery (trigger AFTER UPDATE on_order_delivered_settlements)
CREATE OR REPLACE FUNCTION public.generate_settlements_on_delivery()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_restaurant_commission NUMERIC(12,3);
  v_driver_commission     NUMERIC(12,3);
  v_partner_user_id       UUID;
  v_driver_user_id        UUID;
  v_restaurant_rate       NUMERIC(5,4);
  v_driver_rate           NUMERIC(5,4);
  v_subsidy               NUMERIC(12,3);
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' AND NEW.payment_method = 'cash' THEN

    -- Live rates from global_settings (fall back to defaults if rows missing)
    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_restaurant_commission_rate'),
        0.10
    ) INTO v_restaurant_rate;

    SELECT COALESCE(
        (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'default_driver_commission_rate'),
        0.23
    ) INTO v_driver_rate;

    -- Resolve partner user_id (entity_id::text works for uuid or text column)
    IF NEW.restaurant_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.restaurant_id::text LIMIT 1;
    ELSIF NEW.supermarket_id IS NOT NULL THEN
      SELECT user_id INTO v_partner_user_id
        FROM public.partners WHERE entity_id::text = NEW.supermarket_id::text LIMIT 1;
    END IF;

    -- Resolve driver's auth user_id (orders.driver_id = drivers.id, and
    -- settlements.user_id FKs to auth.users)
    IF NEW.driver_id IS NOT NULL THEN
      SELECT user_id INTO v_driver_user_id
        FROM public.drivers WHERE id = NEW.driver_id LIMIT 1;
    END IF;

    -- Commission cuts
    v_restaurant_commission := NEW.subtotal * v_restaurant_rate;
    IF NEW.self_delivery THEN
      v_driver_commission := 0;
    ELSE
      v_driver_commission := NEW.delivery_fee * v_driver_rate;
    END IF;

    -- Stamp the order with the platform's cuts (non-retroactive)
    UPDATE public.orders
       SET platform_fee   = v_restaurant_commission,
           driver_fee_cut = v_driver_commission
     WHERE id = NEW.id;

    -- Partner: deduct the 10% commission from the restaurant's prepaid balance.
    -- (The partner still receives the food cash directly via the driver; the
    --  wallet only tracks the commission the platform takes.)
    IF v_partner_user_id IS NOT NULL AND v_restaurant_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_partner_user_id,
        'restaurant',
        -v_restaurant_commission,
        'commission_deduction',
        'Commission commande #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    -- Driver: deduct the delivery-fee commission from the driver's prepaid
    -- balance (driver keeps the delivery cash; platform takes its cut here).
    IF NEW.driver_id IS NOT NULL AND NOT NEW.self_delivery
       AND v_driver_user_id IS NOT NULL AND v_driver_commission > 0 THEN
      INSERT INTO public.settlements
        (user_id, entity_type, amount, type, description, related_order_id, status)
      VALUES (
        v_driver_user_id,
        'driver',
        -v_driver_commission,
        'commission_deduction',
        'Commission livraison #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
        NEW.id,
        'paid'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    -- Driver: loyalty subsidy. NEW.loyalty_discount_amount is what the
    -- client was NOT charged (stamped at order creation). Net of the same
    -- commission rate the driver already paid above, so cash collected -
    -- commission + subsidy == a normal full-price delivery's net earning.
    IF NEW.loyalty_milestone_type IS NOT NULL AND NEW.driver_id IS NOT NULL
       AND NOT NEW.self_delivery AND v_driver_user_id IS NOT NULL THEN
      v_subsidy := NEW.loyalty_discount_amount * (1 - v_driver_rate);
      IF v_subsidy > 0 THEN
        INSERT INTO public.settlements
          (user_id, entity_type, amount, type, description, related_order_id, status)
        VALUES (
          v_driver_user_id,
          'driver',
          v_subsidy,
          'loyalty_subsidy',
          'Subvention fidélité (' ||
            CASE NEW.loyalty_milestone_type WHEN 'free' THEN 'livraison gratuite' ELSE '-50% livraison' END ||
            ') #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)),
          NEW.id,
          'paid'
        )
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

  END IF;
  RETURN NEW;
END;
$function$;

-- 3c. apply_promo_code(uuid, text, jsonb, boolean) : les lignes du panier
CREATE OR REPLACE FUNCTION public.apply_promo_code(p_user_id uuid, p_promo_code text, p_items jsonb, p_dry_run boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE

  c_max_lines   CONSTANT INTEGER := 200;
  c_max_qty     CONSTANT INTEGER := 99;

  v_user       UUID;

  v_promo      public.promo_codes%ROWTYPE;
  v_user_uses  INTEGER;
  v_orders     INTEGER;
  v_line       JSONB;
  v_item       public.vendor_items%ROWTYPE;
  v_qty        INTEGER;
  v_variant    NUMERIC;
  v_addons     NUMERIC;
  v_unit       NUMERIC(12,3);
  v_on_promo   BOOLEAN;
  v_lines      INTEGER := 0;
  v_subtotal   NUMERIC(12,3) := 0;
  v_eligible   NUMERIC(12,3) := 0;
  v_discount   NUMERIC(12,3);
  v_new_sub    NUMERIC(12,3);
BEGIN
  v_user := COALESCE(auth.uid(), p_user_id);
  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'NOT_AUTHENTICATED',
      'error_message', 'Vous devez être connecté pour utiliser un code promo',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF p_items IS NULL
     OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > c_max_lines THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EMPTY_CART',
      'error_message', 'Votre panier est vide',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

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
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'INACTIVE',
      'error_message', 'Ce code promo n''est plus actif',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF v_promo.valid_from IS NOT NULL AND now() < v_promo.valid_from THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code n''est pas encore valable',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;
  IF v_promo.expires_at IS NOT NULL AND now() > v_promo.expires_at THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EXPIRED',
      'error_message', 'Ce code a expiré',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MAX_USES_REACHED',
      'error_message', 'Ce code n''est plus disponible',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF v_promo.max_uses_per_customer IS NOT NULL THEN
    SELECT COUNT(*) INTO v_user_uses
      FROM public.user_promo_usages
     WHERE promo_code_id = v_promo.id AND user_id = v_user;

    IF v_user_uses >= v_promo.max_uses_per_customer THEN
      RETURN jsonb_build_object(
        'status', 'error', 'error_code', 'ALREADY_USED',
        'error_message', 'Vous avez déjà utilisé ce code promo',
        'discount_amount', 0, 'new_subtotal', NULL);
    END IF;
  END IF;

  IF v_promo.first_order_only THEN
    SELECT COUNT(*) INTO v_orders
      FROM public.orders o
     WHERE o.user_id = v_user
       AND COALESCE(o.status, '') <> 'cancelled';

    IF v_orders > 0 THEN
      RETURN jsonb_build_object(
        'status', 'error', 'error_code', 'NOT_FIRST_ORDER',
        'error_message', 'Ce code est réservé à votre première commande',
        'discount_amount', 0, 'new_subtotal', NULL);
    END IF;
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_item FROM public.vendor_items
     WHERE id = NULLIF(v_line->>'item_id', '')::uuid;
    CONTINUE WHEN NOT FOUND;

    v_qty := LEAST(GREATEST(COALESCE((v_line->>'quantity')::int, 1), 1), c_max_qty);

    v_variant := NULL;
    IF NULLIF(v_line->>'variant_id', '') IS NOT NULL THEN
      SELECT price INTO v_variant FROM public.food_item_variants
       WHERE id = (v_line->>'variant_id')::uuid;
      IF v_variant IS NULL THEN
        SELECT price INTO v_variant FROM public.grocery_item_variants
         WHERE id = (v_line->>'variant_id')::uuid;
      END IF;
    END IF;

    SELECT COALESCE(SUM(o.price), 0) INTO v_addons
      FROM jsonb_array_elements_text(
             CASE WHEN jsonb_typeof(v_line->'option_ids') = 'array'
                  THEN v_line->'option_ids' ELSE '[]'::jsonb END) AS t(oid)
      JOIN public.food_item_options o ON o.id = t.oid::uuid;

    v_on_promo := v_variant IS NULL
      AND v_item.discount_price IS NOT NULL
      AND (v_item.discount_start_time IS NULL OR v_item.discount_start_time <= now())
      AND (v_item.discount_end_time   IS NULL OR v_item.discount_end_time   >  now());

    v_unit := ROUND(
      (COALESCE(v_variant,
                CASE WHEN v_on_promo THEN v_item.discount_price ELSE v_item.price END)
       + v_addons), 3);

    v_lines    := v_lines + 1;
    v_subtotal := v_subtotal + v_unit * v_qty;
    IF NOT v_on_promo THEN
      v_eligible := v_eligible + v_unit * v_qty;
    END IF;
  END LOOP;

  IF v_lines = 0 THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EMPTY_CART',
      'error_message', 'Votre panier est vide',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF v_promo.min_order_amount IS NOT NULL AND v_subtotal < v_promo.min_order_amount THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MIN_ORDER',
      'error_message', 'Montant minimum de ' || v_promo.min_order_amount
                       || ' TND requis pour ce code',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  IF v_eligible <= 0 THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'ALL_ITEMS_ON_PROMO',
      'error_message', 'Vos articles sont déjà en promotion : le code ne s''applique pas',
      'discount_amount', 0,
      'new_subtotal', v_subtotal,
      'computed_subtotal', v_subtotal,
      'eligible_subtotal', 0);
  END IF;

  IF v_promo.type = 'percentage' THEN
    v_discount := ROUND(v_eligible * (v_promo.value / 100.0), 3);
  ELSE
    v_discount := LEAST(v_promo.value, v_eligible);
  END IF;
  v_new_sub := GREATEST(v_subtotal - v_discount, 0);

  IF NOT p_dry_run THEN
    UPDATE public.promo_codes
       SET used_count = used_count + 1
     WHERE id = v_promo.id;

    INSERT INTO public.user_promo_usages (promo_code_id, user_id)
    VALUES (v_promo.id, v_user);
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'error_code', NULL,
    'error_message', NULL,
    'discount_amount', v_discount,
    'new_subtotal', v_new_sub,
    'computed_subtotal', v_subtotal,
    'eligible_subtotal', v_eligible);
END;
$function$;

-- 3d. apply_promo_code(uuid, text, numeric, boolean) : ancienne signature
CREATE OR REPLACE FUNCTION public.apply_promo_code(p_user_id uuid, p_promo_code text, p_subtotal numeric, p_dry_run boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

-- ── 2. Les prix promo ne sont plus arrondis à l'écriture ─────────────────────
drop trigger if exists round_promo_prices on public.vendor_items;

-- ── 3. Facultatif ───────────────────────────────────────────────────────────
-- Après 1 et 2, plus rien n'appelle round_money ni la fonction du trigger ;
-- elles peuvent rester, comme le réglage money_rounding_step (sans effet).
-- Pour les retirer aussi, enlever les deux tirets au début des 3 lignes :
-- drop function if exists public.round_vendor_item_promo_prices();
-- drop function if exists public.round_money(numeric);
-- delete from public.global_settings where setting_key = 'money_rounding_step';

-- ── Vérification ────────────────────────────────────────────────────────────
-- Attendu : corps_identiques_au_live = 4, fonctions_avec_round_money = 0,
-- trigger_prix_promo = false.
with avant(sig, empreinte) as (
  values ('apply_loyalty_at_checkout()', '1dd06bcce278b43bdd67b8e69feebe0482b7b0896e87fc238b2a7c044e68996a'),
         ('generate_settlements_on_delivery()', '0bfb01d45a2c95bbd1bc2bb9ed102d4cd245d68d046689c6365ed22cfb5e82d4'),
         ('apply_promo_code(uuid,text,jsonb,boolean)', '10a21be5c453f4a0f0bce89a258f123a52fbf4513b5adc13f77c7bdb3fedec90'),
         ('apply_promo_code(uuid,text,numeric,boolean)', '7fb82cfcd924c2fdfe3ed6089f439c3f365ea2f4a0ea4aa5df4940cafbab0821')
)
select (select count(*) from avant a
         where encode(sha256(convert_to(replace(pg_get_functiondef(('public.' || a.sig)::regprocedure),
                                                E'\r\n', E'\n'), 'UTF8')), 'hex') = a.empreinte)
         as corps_identiques_au_live,
       (select count(*) from avant a
         where pg_get_functiondef(('public.' || a.sig)::regprocedure) like '%round_money(%')
         as fonctions_avec_round_money,
       exists (select 1 from pg_trigger where tgrelid = 'public.vendor_items'::regclass
                  and tgname = 'round_promo_prices') as trigger_prix_promo;
