-- ============================================================================
-- CMANDILI — Codes promo, phase 3
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- Trois changements, tous sur apply_promo_code :
--
--   1. Le serveur NE FAIT PLUS CONFIANCE au montant envoyé par l'application.
--   2. Un code peut être réservé à la PREMIÈRE COMMANDE ('BIENVENUE').
--   3. RÈGLE DE CUMUL : le code ne remise que les articles SANS promotion.
--
--
-- ── 1. LE MONTANT N'EST PLUS CELUI DE L'APPLICATION ────────────────────────
--
-- Aujourd'hui la fonction reçoit `p_subtotal numeric` et l'utilise tel quel.
-- Son propre commentaire annonce pourtant : « SECURITY: the frontend NEVER
-- computes the discounted price. » C'est à moitié vrai — l'application ne
-- calcule pas la REMISE, mais elle décide du MONTANT sur lequel elle porte.
-- Un client modifié pouvait envoyer 4000 et repartir avec 400 de remise sur
-- un panier à 40.
--
-- La nouvelle version reçoit les LIGNES du panier (identifiants et quantités,
-- jamais un prix) et relit chaque prix dans `vendor_items`. Le majorant de
-- 10 % de la plateforme est appliqué ici, comme dans CartItem.price, pour que
-- le sous-total serveur soit celui que le client voit.
--
-- Ce que cela ne ferme PAS, et il faut le dire : l'application choisit encore
-- QUELS articles elle déclare. Elle ne peut plus inventer un montant, mais
-- elle pourrait déclarer un panier différent du vrai. Le fermer demande de
-- recalculer `orders.subtotal` depuis `order_items` au moment de l'insertion,
-- par un trigger — à faire dans un second temps, en observant d'abord les
-- écarts réels plutôt qu'en refusant des commandes dès le premier millime.
--
--
-- ── 2. PREMIÈRE COMMANDE ───────────────────────────────────────────────────
--
-- « Première commande » = aucune commande non annulée. Une commande annulée
-- ne compte pas : le client n'a rien reçu, il est encore nouveau. C'est un
-- choix, pas une évidence — si vous préférez compter uniquement les
-- commandes livrées, la condition est à un seul endroit (section 3, bloc 5b).
--
-- Le code est consommé AVANT la création de la commande (checkout_screen
-- appelle apply_promo_code puis createOrder), donc au moment du contrôle la
-- première commande n'existe pas encore : le compte est bien à zéro.
--
--
-- ── 3. RÈGLE DE CUMUL ──────────────────────────────────────────────────────
--
-- La promotion d'article — ou le Happy Hour — EST le prix. Le code promo
-- s'applique ensuite, mais seulement sur les articles qui n'en ont pas.
-- Sans cette règle un article à −50 % recevrait encore −20 %, soit −60 %, et
-- la commission du partenaire serait calculée sur un montant qu'il n'a jamais
-- accepté. La remise fidélité ne touche que les frais de livraison, elle
-- reste donc cumulable avec tout le reste — elle n'apparaît pas ici.
--
-- Cette règle est la RAISON pour laquelle le calcul doit être serveur : on ne
-- peut pas répartir un sous-total qu'on n'a pas calculé soi-même.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. État avant ──────────────────────────────────────────────────────────
SELECT code, type, value, min_order_amount, max_uses, used_count,
       max_uses_per_customer, is_active, valid_from, expires_at
FROM public.promo_codes
ORDER BY created_at;

SELECT p.oid::regprocedure::text AS signature,
       array_to_string(p.proacl, ' | ')  AS droits
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'apply_promo_code';


BEGIN;

-- ── 1. La colonne « première commande » ────────────────────────────────────
ALTER TABLE public.promo_codes
  ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.promo_codes.first_order_only IS
  'Réservé aux clients n''ayant aucune commande non annulée (code de bienvenue).';


-- ── 2. La nouvelle fonction ────────────────────────────────────────────────
-- Surcharge : `p_items jsonb` au lieu de `p_subtotal numeric`. PostgREST
-- choisit d'après les noms d'arguments envoyés, les deux cohabitent donc sans
-- ambiguïté le temps que l'application soit mise à jour.
--
-- p_items attend :
--   [{"item_id":"<uuid>", "quantity":2,
--     "variant_id":"<uuid>|null", "option_ids":["<uuid>", ...]}]
--
-- Aucun prix n'y figure. C'est tout l'objet du changement.
CREATE OR REPLACE FUNCTION public.apply_promo_code(
  p_user_id    UUID,
  p_promo_code TEXT,
  p_items      JSONB,
  p_dry_run    BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  -- Le majorant plateforme, identique à kPlatformMarkupRate côté application.
  -- Le partenaire et le livreur lisent le prix nu ; le client paie celui-ci.
  c_markup   CONSTANT NUMERIC := 1.10;
  -- Garde-fous sur l'entrée : un panier réel n'a ni 500 lignes ni 500 unités.
  c_max_lines   CONSTANT INTEGER := 200;
  c_max_qty     CONSTANT INTEGER := 99;

  -- L'utilisateur RÉEL. auth.uid() vient du jeton signé ; p_user_id vient de
  -- l'application, qui pouvait donc consommer le code d'un autre client. On ne
  -- retombe sur le paramètre que lorsqu'il n'y a pas de jeton -- appel
  -- service_role depuis le tableau de bord ou un script.
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

  -- ── 0. L'entrée ──────────────────────────────────────────────────────────
  IF p_items IS NULL
     OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > c_max_lines THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'EMPTY_CART',
      'error_message', 'Votre panier est vide',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  -- ── 1. Le code ───────────────────────────────────────────────────────────
  -- FOR UPDATE sur le chemin d'écriture seulement : deux commandes simultanées
  -- avec le dernier exemplaire d'un code ne doivent pas passer toutes les deux.
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

  -- ── 2. Actif ─────────────────────────────────────────────────────────────
  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'INACTIVE',
      'error_message', 'Ce code promo n''est plus actif',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  -- ── 3. Fenêtre de validité ───────────────────────────────────────────────
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

  -- ── 4. Plafond global ────────────────────────────────────────────────────
  IF v_promo.max_uses IS NOT NULL AND v_promo.used_count >= v_promo.max_uses THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MAX_USES_REACHED',
      'error_message', 'Ce code n''est plus disponible',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  -- ── 5. Plafond par client ────────────────────────────────────────────────
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

  -- ── 5b. Première commande ────────────────────────────────────────────────
  -- Les commandes annulées ne comptent pas : le client n'a jamais rien reçu.
  -- Pour n'accepter que les commandes livrées, remplacer la condition par
  --   AND o.status = 'delivered'
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

  -- ── 6. Le sous-total, calculé ICI ────────────────────────────────────────
  -- Chaque ligne est relue en base. Une ligne dont l'article n'existe plus est
  -- ignorée plutôt que de faire échouer l'opération : le panier de
  -- l'application peut contenir un article retiré du catalogue entre temps, et
  -- refuser le code ne dirait rien d'utile au client.
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_item FROM public.vendor_items
     WHERE id = NULLIF(v_line->>'item_id', '')::uuid;
    CONTINUE WHEN NOT FOUND;

    v_qty := LEAST(GREATEST(COALESCE((v_line->>'quantity')::int, 1), 1), c_max_qty);

    -- Une variante REMPLACE le prix de base (CartItem.price fait de même), et
    -- une variante n'est jamais remisée : la ligne reste donc éligible au code.
    v_variant := NULL;
    IF NULLIF(v_line->>'variant_id', '') IS NOT NULL THEN
      SELECT price INTO v_variant FROM public.food_item_variants
       WHERE id = (v_line->>'variant_id')::uuid;
      IF v_variant IS NULL THEN
        SELECT price INTO v_variant FROM public.grocery_item_variants
         WHERE id = (v_line->>'variant_id')::uuid;
      END IF;
    END IF;

    -- Suppléments choisis (harissa, gruyère…). Somme brute : le majorant
    -- plateforme s'applique UNE fois sur le total de la ligne, jamais par
    -- composant — exactement comme CartItem.price.
    SELECT COALESCE(SUM(o.price), 0) INTO v_addons
      FROM jsonb_array_elements_text(
             CASE WHEN jsonb_typeof(v_line->'option_ids') = 'array'
                  THEN v_line->'option_ids' ELSE '[]'::jsonb END) AS t(oid)
      JOIN public.food_item_options o ON o.id = t.oid::uuid;

    -- L'article porte-t-il une promotion VIVANTE ?
    --
    -- Même lecture que VendorItem.effectivePrice côté client : un prix remisé,
    -- une fenêtre ouverte. `discount_start_time` est vérifié par principe —
    -- depuis la phase 2 une promotion programmée n'a pas encore de prix, mais
    -- s'appuyer sur cette coïncidence serait fragile.
    --
    -- Le mécanisme historique is_happy_hour / happy_hour_price n'est PAS lu,
    -- délibérément : il est à zéro ligne en base et le panier du client ne le
    -- lit pas non plus. Le lire ici ferait diverger les deux totaux.
    v_on_promo := v_variant IS NULL
      AND v_item.discount_price IS NOT NULL
      AND (v_item.discount_start_time IS NULL OR v_item.discount_start_time <= now())
      AND (v_item.discount_end_time   IS NULL OR v_item.discount_end_time   >  now());

    v_unit := ROUND(
      (COALESCE(v_variant,
                CASE WHEN v_on_promo THEN v_item.discount_price ELSE v_item.price END)
       + v_addons) * c_markup, 3);

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

  -- ── 7. Montant minimum ───────────────────────────────────────────────────
  -- Sur le sous-total COMPLET : c'est ce que le client dépense réellement, y
  -- compris ses articles déjà en promotion.
  IF v_promo.min_order_amount IS NOT NULL AND v_subtotal < v_promo.min_order_amount THEN
    RETURN jsonb_build_object(
      'status', 'error', 'error_code', 'MIN_ORDER',
      'error_message', 'Montant minimum de ' || v_promo.min_order_amount
                       || ' TND requis pour ce code',
      'discount_amount', 0, 'new_subtotal', NULL);
  END IF;

  -- ── 8. La remise, sur la part éligible seulement ─────────────────────────
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
    -- Montant fixe : plafonné à la part éligible, sinon un code de 10 TND
    -- viderait un panier de 8 TND déjà remisé.
    v_discount := LEAST(v_promo.value, v_eligible);
  END IF;
  v_new_sub := GREATEST(v_subtotal - v_discount, 0);

  -- ── 9. Chemin d'écriture ─────────────────────────────────────────────────
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
    -- Les deux champs suivants sont nouveaux : ils permettent à l'écran de
    -- dire « −3.500 DT sur 12.000 DT éligibles » plutôt qu'un montant sans
    -- explication, et de repérer un écart avec le total affiché.
    'computed_subtotal', v_subtotal,
    'eligible_subtotal', v_eligible);
END;
$fn$;

-- Même raison qu'à la section 3 ci-dessous : sans le REVOKE sur PUBLIC, un
-- appelant `anon` pourrait consommer le code d'un client connecté. Le GRANT
-- nominatif qui suit est ce qui rend la fonction appelable.
REVOKE EXECUTE ON FUNCTION
  public.apply_promo_code(UUID, TEXT, JSONB, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.apply_promo_code(UUID, TEXT, JSONB, BOOLEAN)
  TO authenticated, service_role;


-- ── 3. Fermer l'ancienne porte ─────────────────────────────────────────────
-- L'ancienne signature reste en place — d'autres appelants pourraient
-- l'utiliser — mais un client ne doit plus pouvoir l'appeler, sinon le trou
-- du montant envoyé par l'application reste grand ouvert à côté de sa
-- correction.
--
-- CONSÉQUENCE : une version de l'application antérieure à cette migration
-- reçoit « permission denied » sur la saisie d'un code promo. C'est un échec
-- visible et sans dégât (le reste de la commande fonctionne), préféré à un
-- trou silencieux. Si vous voulez laisser un délai aux téléphones déjà
-- installés, commentez la ligne ci-dessous et revenez la passer plus tard.
-- REVOKE ... FROM authenticated NE SUFFIT PAS, et le garde-fou de la section
-- 4 l'a prouvé en refusant cette migration à sa première écriture : Postgres
-- accorde EXECUTE à PUBLIC par défaut sur toute fonction, et `authenticated`
-- en hérite. Retirer son droit nominatif laissait donc la fonction appelable,
-- c'est-à-dire le trou grand ouvert à côté de sa correction.
--
-- Il faut retirer le droit de PUBLIC, puis le redonner nommément à qui doit
-- l'avoir -- sans quoi service_role le perdrait aussi et le tableau de bord
-- cesserait de pouvoir simuler un code.
REVOKE EXECUTE ON FUNCTION
  public.apply_promo_code(UUID, TEXT, NUMERIC, BOOLEAN)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.apply_promo_code(UUID, TEXT, NUMERIC, BOOLEAN) TO service_role;


-- ── 4. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema='public' AND table_name='promo_codes'
     AND column_name='first_order_only';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : first_order_only absente de promo_codes';
  END IF;

  SELECT count(*) INTO n FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'apply_promo_code';
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : % version(s) d''apply_promo_code au lieu de 2', n;
  END IF;

  IF has_function_privilege('authenticated',
       'public.apply_promo_code(uuid,text,numeric,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Abandon : l''ancienne signature est encore exécutable par authenticated';
  END IF;

  IF NOT has_function_privilege('authenticated',
       'public.apply_promo_code(uuid,text,jsonb,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Abandon : la nouvelle signature n''est pas exécutable par authenticated';
  END IF;

  IF has_function_privilege('anon',
       'public.apply_promo_code(uuid,text,jsonb,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Abandon : la nouvelle signature est appelable sans être connecté';
  END IF;

  IF NOT has_function_privilege('service_role',
       'public.apply_promo_code(uuid,text,numeric,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Abandon : service_role a perdu l''ancienne signature';
  END IF;
END
$$;

COMMIT;


-- ── B. Le code BIENVENUE ───────────────────────────────────────────────────
-- NON INSÉRÉ : créer un code de réduction est une décision commerciale, pas
-- une conséquence technique. Décommentez et ajustez le montant, ou créez-le
-- depuis le tableau de bord admin.
--
-- INSERT INTO public.promo_codes
--   (code, type, value, min_order_amount, max_uses_per_customer,
--    first_order_only, is_active)
-- VALUES
--   ('BIENVENUE', 'percentage', 20, 15, 1, TRUE, TRUE)
-- ON CONFLICT DO NOTHING;


-- ── C. État après ──────────────────────────────────────────────────────────
SELECT p.oid::regprocedure::text AS signature,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS client_peut_appeler
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'apply_promo_code'
ORDER BY 1;
-- Attendu : la version (…,numeric,…) à false, la version (…,jsonb,…) à true.

SELECT code, first_order_only, type, value, is_active
FROM public.promo_codes
ORDER BY created_at;
