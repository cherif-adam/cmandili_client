-- ============================================================================
-- CMANDILI -- Promotions, phase 2 : le complément base
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- Deux manques apparus en branchant l'app partenaire sur la phase 1.
--
--
-- 1. UNE PROMOTION PROGRAMMÉE PARTIRAIT IMMÉDIATEMENT.
--
-- Relevé avant écriture : AUCUN lecteur de remise, dans aucune des quatre
-- applications, ne regarde `discount_start_time`.
--
--   client  lib/core/models/vendor.dart:144   effectivePrice -> fin seulement
--   panier  cart_item.dart:113                délègue à effectivePrice
--   admin   aucune lecture de la colonne
--
-- Autrement dit, si l'app partenaire écrivait `discount_price` en même temps
-- qu'une date de début future, la remise partirait à la seconde même -- une
-- semaine avant la braderie prévue, avec la commission calculée dessus.
--
-- La correction ne touche AUCUN lecteur : l'app partenaire n'écrit plus le
-- prix d'une promotion programmée (elle n'enregistre que le taux et les deux
-- dates), et le job ci-dessous le pose à l'instant du début. Tant que
-- `discount_price` est NULL, tout le monde voit le prix normal -- ce qui est
-- exactement le comportement voulu, sans une ligne de Dart modifiée ailleurs.
--
-- Sans ce job, une promotion programmée ne démarrerait jamais.
--
--
-- 2. LA VUE grocery_items N'EXPOSE PAS LES DEUX NOUVELLES COLONNES.
--
-- La phase 1 les a ajoutées à la TABLE `vendor_items`. Le supermarché est en
-- mode `percent`, mais son catalogue passe par la vue `grocery_items`, qui
-- s'arrête à discount_price / discount_end_time / discount_quantity. Sans
-- elles, la carte d'un article de supermarché ne peut afficher ni le taux
-- ("−20 %") ni l'état « programmée » -- le commerçant croirait que son
-- enregistrement a échoué.
--
-- `food_items` n'est volontairement PAS touchée : la catégorie food est en
-- Happy Hour, elle n'a pas de pourcentage à montrer.
--
-- L'écriture, elle, n'a jamais eu besoin de la vue : setPercentPromo écrit
-- directement dans `vendor_items`, où vivent tous les identifiants d'article.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================


-- ── A. État avant ──────────────────────────────────────────────────────────
SELECT count(*) FILTER (WHERE discount_price   IS NOT NULL) AS avec_prix,
       count(*) FILTER (WHERE discount_percent IS NOT NULL) AS avec_taux,
       count(*) FILTER (WHERE discount_percent IS NOT NULL
                          AND discount_price   IS NULL)     AS programmees
FROM public.vendor_items;


BEGIN;

-- ── 1. Les promotions programmées démarrent toutes seules ──────────────────
-- Le prix est recalculé depuis le prix courant de l'article, pas depuis celui
-- qu'il avait au moment du réglage : si le commerçant change son tarif entre
-- temps, la remise suit. C'est le sens d'un pourcentage.
--
-- `round(..., 3)` : le millime est l'unité réelle du dinar et la précision de
-- la colonne. C'est le même arrondi que computePromoPrice côté application,
-- donc le prix affiché avant l'enregistrement reste celui qui sera encaissé.
--
-- La condition sur la fin évite de réveiller une promotion déjà expirée : le
-- job clear_expired_promotions (phase 1) tourne aussi chaque minute et la
-- nettoierait aussitôt, les deux se battraient pour rien.
SELECT cron.schedule(
  'activate_scheduled_promotions',
  '* * * * *',
  $job$
    UPDATE public.vendor_items
    SET    discount_price = round(price * (1 - discount_percent / 100.0), 3)
    WHERE  discount_percent    IS NOT NULL
      AND  discount_price      IS NULL
      AND  discount_start_time IS NOT NULL
      AND  discount_start_time <= now()
      AND  (discount_end_time IS NULL OR discount_end_time > now());
  $job$
);


-- ── 2. La vue grocery_items expose le taux et le début ─────────────────────
-- CREATE OR REPLACE VIEW : les deux colonnes sont AJOUTÉES EN FIN de liste,
-- la seule modification que Postgres accepte sur une vue existante. L'ordre
-- et le type des colonnes actuelles sont repris à l'identique depuis
-- pg_get_viewdef, et le trigger INSTEAD OF grocery_items_write_trg reste
-- attaché -- les écritures du supermarché ne changent pas.
CREATE OR REPLACE VIEW public.grocery_items AS
  SELECT vi.id,
         vi.vendor_id AS supermarket_id,
         vi.name,
         vi.description,
         vi.image_url,
         vi.price,
         vi.category,
         vi.unit,
         vi.is_organic,
         vi.is_available,
         vi.discount_price,
         vi.discount_end_time,
         vi.created_at,
         vi.discount_quantity,
         vi.discount_percent,
         vi.discount_start_time
    FROM vendor_items vi
    JOIN vendors v ON v.id = vi.vendor_id
   WHERE v.category = 'grocery'::text;


-- ── 3. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM cron.job
   WHERE jobname = 'activate_scheduled_promotions';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : activate_scheduled_promotions n''est pas planifié';
  END IF;

  SELECT count(*) INTO n FROM cron.job
   WHERE jobname = 'clear_expired_promotions';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : clear_expired_promotions a disparu (phase 1 rejouée ?)';
  END IF;

  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'grocery_items'
     AND column_name IN ('discount_percent', 'discount_start_time');
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : % colonne(s) de remise sur 2 exposées par grocery_items', n;
  END IF;

  SELECT count(*) INTO n FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'grocery_items'
     AND t.tgname  = 'grocery_items_write_trg'
     AND NOT t.tgisinternal;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : le trigger d''écriture de grocery_items a été perdu';
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname IN ('activate_scheduled_promotions', 'clear_expired_promotions')
ORDER BY jobname;
-- Attendu : deux lignes, '* * * * *', active = true.

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'grocery_items'
  AND column_name LIKE 'discount%'
ORDER BY column_name;
-- Attendu : discount_end_time, discount_percent, discount_price,
--           discount_quantity, discount_start_time.
