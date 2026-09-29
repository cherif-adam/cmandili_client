-- ============================================================================
-- CMANDILI — `orders.order_type` dit enfin la vérité
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- Aujourd'hui la colonne ment. Le checkout calcule
--   order_type = 'supermarket' si la ligne est de l'épicerie, sinon 'food'
-- donc une commande de fleurs, de cadeaux ou d'électronique est enregistrée
-- comme une commande de restaurant. Relevé exact avant écriture :
--
--   order_type   catégorie réelle du commerce   lignes
--   food         food                              101   ← juste
--   food         gifts                              14   ← faux
--   food         electronics                         3   ← faux
--   food         flowers                             1   ← faux
--   food         (commerce introuvable)              5   ← laissées telles
--   courier      —                                  23
--   facture      —                                  14
--
--   supermarket                                      0   ← jamais écrit
--
-- Rien n'est visiblement cassé parce que le seul écran qui comptait —
-- « chiffre d'affaires par catégorie » — ignore délibérément la colonne et
-- remonte à la catégorie du commerce. Mais tout export ou rapport écrit
-- demain en partant de `order_type` serait faux dès le premier jour.
--
--
-- ── L'ORDRE DES TROIS SECTIONS N'EST PAS ARBITRAIRE ────────────────────────
--
-- Deux lecteurs filtrent sur la valeur 'food', et les commandes de boutique
-- ne passent aujourd'hui que parce qu'elles sont MAL étiquetées :
--
--   apply_loyalty_at_checkout   order_type IN ('food','courier','facture')
--   order_ratings (policy)      o.order_type = 'food'
--
-- Écrire les vraies catégories AVANT de corriger ces deux-là ferait
-- silencieusement perdre la fidélité et la notation à 18 commandes par mois,
-- sans une seule erreur nulle part. D'où : on élargit la contrainte (1), on
-- rend les deux lecteurs indépendants de 'food' (2), et seulement ensuite on
-- réécrit les données (3).
--
-- Le comportement métier ne change PAS :
--   • le supermarché continue de ne rien rapporter en fidélité ;
--   • toute commande de commerce reste notable, colis et factures non.
--
-- La fidélité déjà acquise n'est pas touchée : loyalty_customer_progress
-- compte des commandes passées, et ce fichier ne le lit ni ne l'écrit.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. État avant ──────────────────────────────────────────────────────────
SELECT o.order_type,
       COALESCE(v.category, '(commerce introuvable)') AS categorie_reelle,
       count(*) AS lignes
FROM public.orders o
LEFT JOIN public.vendors v ON v.id = COALESCE(o.restaurant_id, o.supermarket_id)
GROUP BY 1, 2
ORDER BY 3 DESC;


BEGIN;

-- ── 1. La contrainte accepte une valeur par catégorie ──────────────────────
-- Les anciennes valeurs restent autorisées : 'supermarket' et 'billPayment'
-- n'ont plus d'usage mais des lignes historiques pourraient les porter, et
-- une contrainte qui rendrait illégal l'existant refuserait la migration
-- elle-même.
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_order_type_check;
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_order_type_valid;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_order_type_check
  CHECK (order_type IN (
    -- Une valeur par catégorie de commerce, les mêmes identifiants que
    -- `vendors.category` et `vendor_categories.id` : une seule liste à tenir.
    'food', 'grocery', 'bakery', 'flowers', 'pets', 'gifts', 'electronics',
    -- Les services sans catalogue.
    'courier', 'facture',
    -- Historique, plus jamais écrites.
    'supermarket', 'billPayment'
  ));


-- ── 2. Les deux lecteurs cessent de dépendre de 'food' ─────────────────────

-- 2a. Fidélité. La règle voulue est « tout sauf le supermarché », pas « food,
-- colis et facture » : c'était la même chose tant que les boutiques étaient
-- étiquetées food, ça ne l'est plus. 'grocery' rejoint 'supermarket' dans
-- l'exclusion, puisque c'est la valeur que la section 3 écrira désormais.
CREATE OR REPLACE FUNCTION public.apply_loyalty_at_checkout()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $fn$
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
$fn$;

-- 2b. Notation. On note un COMMERCE : tout ce qui en a un reste notable, un
-- colis ou une facture n'en a pas. Le reste de la policy est repris à
-- l'identique — c'est elle qui garantit qu'on ne note que sa propre commande,
-- livrée, et le commerce qui l'a effectivement servie.
DROP POLICY IF EXISTS order_ratings_insert_own_delivered ON public.order_ratings;

CREATE POLICY order_ratings_insert_own_delivered
  ON public.order_ratings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.orders o
       WHERE o.id = order_ratings.order_id
         AND o.user_id = auth.uid()
         AND o.status = 'delivered'
         AND o.order_type NOT IN ('courier', 'facture', 'billPayment')
         AND o.restaurant_id = order_ratings.restaurant_id
    )
  );


-- ── 3. Les données disent la vérité ────────────────────────────────────────
-- 18 lignes changent : 14 gifts, 3 electronics, 1 flowers. Les 5 commandes
-- dont le commerce n'existe plus gardent 'food' — inventer une catégorie pour
-- elles serait pire que l'imprécision qu'on corrige.
UPDATE public.orders o
   SET order_type = v.category
  FROM public.vendors v
 WHERE v.id = COALESCE(o.restaurant_id, o.supermarket_id)
   AND o.order_type IN ('food', 'supermarket')
   AND o.order_type <> v.category
   AND v.category IN ('food', 'grocery', 'bakery', 'flowers', 'pets',
                      'gifts', 'electronics');


-- ── 4. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  -- Plus aucune commande n'est etiquetee autrement que sa boutique.
  SELECT count(*) INTO n
    FROM public.orders o
    JOIN public.vendors v ON v.id = COALESCE(o.restaurant_id, o.supermarket_id)
   WHERE o.order_type <> v.category
     AND o.order_type NOT IN ('courier', 'facture');
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % commande(s) portent encore un type different de leur boutique', n;
  END IF;

  -- Aucune valeur orpheline : tout ce qui reste est lisible par les lecteurs.
  SELECT count(*) INTO n FROM public.orders
   WHERE order_type NOT IN ('food','grocery','bakery','flowers','pets','gifts',
                            'electronics','courier','facture','supermarket',
                            'billPayment');
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % commande(s) portent un order_type inconnu', n;
  END IF;

  -- La fidelite ne doit plus dependre de 'food'.
  SELECT count(*) INTO n FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'apply_loyalty_at_checkout'
     AND pg_get_functiondef(p.oid) LIKE '%NOT IN (''supermarket'', ''grocery''%';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : apply_loyalty_at_checkout filtre encore sur food';
  END IF;

  -- La notation non plus.
  SELECT count(*) INTO n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'order_ratings'
     AND policyname = 'order_ratings_insert_own_delivered'
     AND with_check LIKE '%courier%';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la policy de notation filtre encore sur food';
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT o.order_type,
       COALESCE(v.category, '(commerce introuvable)') AS categorie_reelle,
       count(*) AS lignes
FROM public.orders o
LEFT JOIN public.vendors v ON v.id = COALESCE(o.restaurant_id, o.supermarket_id)
GROUP BY 1, 2
ORDER BY 3 DESC;
-- Attendu : food/food 101, courier 23, gifts/gifts 14, facture 14,
--           food/(commerce introuvable) 5, electronics/electronics 3,
--           flowers/flowers 1. Plus aucune ligne ou les deux colonnes
--           divergent, hors colis et factures.
