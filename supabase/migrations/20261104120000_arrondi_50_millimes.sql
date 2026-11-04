-- ============================================================================
-- CMANDILI / Amana — Arrondi des montants à 50 millimes
--
-- À lancer dans le SQL Editor (projet cmandili), puis
-- `supabase migration repair --status applied 20261104120000 --linked`.
-- Ne pas passer par `supabase db push`.
--
-- ── CONSTAT (live, 04/11) ───────────────────────────────────────────────────
-- La base calcule l'argent au millime (NUMERIC(12,3)). À 3 km (3,500 DT) la
-- commission livreur vaut 0,805 DT ; à la 5e commande, 0,403 DT de commission
-- et 1,348 DT de subvention fidélité. En Tunisie personne ne paie ni ne compte
-- des millimes isolés. Sur les 184 commandes du live, 44 frais de livraison,
-- 30 commissions commerçant et 56 commissions livreur ne sont pas des
-- multiples de 50 millimes.
--
-- ── RÈGLE ───────────────────────────────────────────────────────────────────
-- round_money(x) = le multiple du pas le plus proche, moitié vers le haut :
-- 0,805 -> 0,800 ; 0,4025 -> 0,400 ; 1,035 -> 1,050 ; 2,375 -> 2,400.
-- Le pas est le réglage global_settings.money_rounding_step (0.050 par défaut).
--   frais facturés        = round_money(frais calculés)
--   5e commande           : payé = round_money(frais / 2), remise = frais - payé
--   10e commande          : payé = 0, remise = frais
--   commission commerçant = round_money(sous-total x taux commerçant)
--   commission livreur    = round_money(frais payés x taux livreur)
--   subvention fidélité   = (frais - round_money(frais x taux livreur))
--                           - (frais payés - commission payée)
-- La subvention n'est PAS arrondie à part : c'est elle qui garantit que le
-- livreur garde exactement ce qu'il garde sur une commande normale, et que la
-- plateforme paie exactement la remise. Les règles 23 % / 77 %, les
-- conditions des fonctions et l'index settlements_once_per_order ne changent
-- pas.
--
-- ── CE QUE FAIT CE FICHIER ──────────────────────────────────────────────────
--   1. Ajoute le réglage money_rounding_step (0.050) sans écraser une valeur
--      déjà présente.
--   2. Crée public.round_money(numeric).
--   3. Remplace 4 fonctions. Chaque corps part de la définition LIVE du 04/11
--      (pg_get_functiondef) ; seules les lignes marquées [arrondi 50 millimes]
--      changent :
--        apply_loyalty_at_checkout        frais arrondis, payé de la 5e commande
--        generate_settlements_on_delivery commissions et subvention
--        apply_promo_code (panier)        remise en pourcentage
--        apply_promo_code (sous-total)    remise en pourcentage (ancienne
--                                         signature, que l'app n'appelle plus)
--   4. Ajoute un trigger BEFORE sur vendor_items qui arrondit discount_price
--      et happy_hour_price à l'écriture : Happy Hour, promotions en
--      pourcentage de l'app partenaire, et le cron
--      activate_scheduled_promotions qui calcule encore ce prix au millime.
--      Le prix promo ne dépasse jamais le prix normal de l'article.
--
-- Aucune ligne existante de orders, settlements, wallets ou vendor_items
-- n'est modifiée par ce fichier. Les nouvelles règles valent pour les
-- commandes créées après (frais, fidélité) et pour les règlements écrits
-- après (commissions, subvention, au passage à « livrée »).
-- Retour arrière : presentation_assets/rollback_arrondi.sql.
-- ============================================================================

-- ── 1. Le pas d'arrondi, modifiable dans l'admin comme les taux ─────────────
insert into public.global_settings (setting_key, setting_value, description)
values ('money_rounding_step', '0.050',
        'Pas d''arrondi des montants calculés, en DT (0.050 = 50 millimes).')
on conflict (setting_key) do nothing;

-- ── 2. round_money(x) ───────────────────────────────────────────────────────
-- Le multiple du pas le plus proche, moitié vers le haut (en valeur absolue,
-- comme ROUND). Un réglage absent, illisible ou <= 0 vaut 0.050 : une valeur
-- mal saisie dans l'admin ne doit jamais bloquer une commande.
-- Postgres ignore la précision écrite dans RETURNS : le cast final garantit
-- le numeric(12,3).
create or replace function public.round_money(x numeric)
returns numeric
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_raw  text;
  v_step numeric;
begin
  if x is null then
    return null;
  end if;

  select setting_value into v_raw
    from public.global_settings
   where setting_key = 'money_rounding_step';

  if v_raw ~ '^\s*[0-9]*\.?[0-9]+\s*$' then
    v_step := trim(v_raw)::numeric;
  end if;
  if v_step is null or v_step <= 0 then
    v_step := 0.050;
  end if;

  return (round(x / v_step) * v_step)::numeric(12,3);
end;
$function$;

comment on function public.round_money(numeric) is
  'Arrondit un montant (DT) au multiple de global_settings.money_rounding_step le plus proche, moitié vers le haut. Retour numeric(12,3).';

-- ── 3. Les 4 fonctions, depuis leur définition live ─────────────────────────

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
  v_fee       NUMERIC(12,3);
BEGIN
  -- [arrondi 50 millimes] Les frais factures au client sont un multiple du
  -- pas (global_settings.money_rounding_step). L'app les arrondit deja ;
  -- ceci couvre une version plus ancienne de l'app. total contient
  -- delivery_fee une seule fois : il recoit le meme ecart.
  IF NEW.delivery_fee IS NOT NULL THEN
    v_fee            := public.round_money(NEW.delivery_fee);
    NEW.total        := NEW.total + (v_fee - NEW.delivery_fee);
    NEW.delivery_fee := v_fee;
  END IF;

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
      -- [arrondi 50 millimes] le client paie round_money(frais / 2) ;
      -- la remise est le reste, pour que frais = paye + remise.
      v_discount  := NEW.delivery_fee - public.round_money(NEW.delivery_fee * 0.5);
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
  v_full_fee              NUMERIC(12,3);
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
    -- [arrondi 50 millimes] commissions ramenees au pas monetaire.
    v_restaurant_commission := public.round_money(NEW.subtotal * v_restaurant_rate);
    IF NEW.self_delivery THEN
      v_driver_commission := 0;
    ELSE
      v_driver_commission := public.round_money(NEW.delivery_fee * v_driver_rate);
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
      -- [arrondi 50 millimes] Le livreur garde exactement ce qu'il garderait
      -- sur une commande normale : frais complets - round_money(frais
      -- complets x taux). La subvention comble l'ecart avec ce qu'il a
      -- vraiment garde (frais payes - commission payee). Elle n'est pas
      -- arrondie a part : la plateforme paie ainsi exactement la remise.
      v_full_fee := NEW.delivery_fee + COALESCE(NEW.loyalty_discount_amount, 0);
      v_subsidy  := (v_full_fee - public.round_money(v_full_fee * v_driver_rate))
                    - (NEW.delivery_fee - v_driver_commission);
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
    -- [arrondi 50 millimes] remise au pas monetaire, jamais plus que l'eligible.
    v_discount := LEAST(public.round_money(v_eligible * (v_promo.value / 100.0)), v_eligible);
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
    -- [arrondi 50 millimes] remise au pas monetaire, jamais plus que le sous-total.
    v_discount := LEAST(public.round_money(p_subtotal * (v_promo.value / 100.0)), p_subtotal);
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

-- ── 4. Prix promo arrondis à l'écriture (vendor_items) ──────────────────────
-- discount_price : Happy Hour (app partenaire), promotion en % (app
-- partenaire), cron activate_scheduled_promotions. happy_hour_price : Happy
-- Hour quotidien saisi dans la fiche article. LEAST(..., price) : l'arrondi ne
-- peut jamais rendre le prix promo plus cher que le prix normal (seulement
-- possible si le prix normal n'est pas lui-même un multiple du pas).
create or replace function public.round_vendor_item_promo_prices()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.discount_price is not null then
    new.discount_price := least(public.round_money(new.discount_price), new.price);
  end if;
  if new.happy_hour_price is not null then
    new.happy_hour_price := least(public.round_money(new.happy_hour_price), new.price);
  end if;
  return new;
end;
$function$;

comment on function public.round_vendor_item_promo_prices() is
  'Trigger BEFORE de vendor_items : arrondit discount_price et happy_hour_price avec round_money, sans dépasser price.';

create or replace trigger round_promo_prices
  before insert or update of discount_price, happy_hour_price on public.vendor_items
  for each row execute function public.round_vendor_item_promo_prices();

-- ── Contrôle : tout ou rien ─────────────────────────────────────────────────
do $check$
begin
  if (select setting_value from public.global_settings
       where setting_key = 'money_rounding_step') ~ '^\s*0*\.050*\s*$' then
    if public.round_money(0.805)  <> 0.800 or public.round_money(0.4025) <> 0.400
       or public.round_money(1.035) <> 1.050 or public.round_money(2.375) <> 2.400
       or public.round_money(1.348) <> 1.350 or public.round_money(4.185) <> 4.200 then
      raise exception 'arrondi_50_millimes : round_money ne donne pas les valeurs attendues';
    end if;
  end if;

  if (select count(*) from (values ('public.apply_loyalty_at_checkout()'),
                                   ('public.generate_settlements_on_delivery()'),
                                   ('public.apply_promo_code(uuid,text,jsonb,boolean)'),
                                   ('public.apply_promo_code(uuid,text,numeric,boolean)')) f(sig)
       where pg_get_functiondef(f.sig::regprocedure) like '%public.round_money(%') <> 4 then
    raise exception 'arrondi_50_millimes : une des 4 fonctions n''appelle pas round_money';
  end if;

  if not exists (select 1 from pg_indexes where schemaname = 'public'
                    and indexname = 'settlements_once_per_order') then
    raise exception 'arrondi_50_millimes : index settlements_once_per_order absent';
  end if;
end
$check$;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : pas = 0.050, r_0_805 = 0.800, r_0_4025 = 0.400, r_1_035 = 1.050,
-- r_2_375 = 2.400, fonctions_a_jour = 4, trigger_prix_promo = true,
-- index_unique_intact = true.
select (select setting_value from public.global_settings
         where setting_key = 'money_rounding_step') as pas,
       public.round_money(0.805)  as r_0_805,
       public.round_money(0.4025) as r_0_4025,
       public.round_money(1.035)  as r_1_035,
       public.round_money(2.375)  as r_2_375,
       (select count(*) from (values ('public.apply_loyalty_at_checkout()'),
                                     ('public.generate_settlements_on_delivery()'),
                                     ('public.apply_promo_code(uuid,text,jsonb,boolean)'),
                                     ('public.apply_promo_code(uuid,text,numeric,boolean)')) f(sig)
         where pg_get_functiondef(f.sig::regprocedure) like '%public.round_money(%') as fonctions_a_jour,
       exists (select 1 from pg_trigger where tgrelid = 'public.vendor_items'::regclass
                  and tgname = 'round_promo_prices' and tgenabled = 'O') as trigger_prix_promo,
       exists (select 1 from pg_indexes where schemaname = 'public'
                  and indexname = 'settlements_once_per_order') as index_unique_intact;
