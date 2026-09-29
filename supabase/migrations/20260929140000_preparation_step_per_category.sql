-- ============================================================================
-- CMANDILI — L'étape « préparation » appartient à la catégorie
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- Une commande d'électronique affichait « Preparing » dans le suivi client.
-- Deux causes, et aucune des deux n'est une faute d'affichage :
--
--   1. L'écran de suivi n'a qu'UNE frise pour tout ce qui n'est ni colis ni
--      facture, avec une étape « Preparing » écrite en dur. Rien n'y
--      distingue un restaurant d'un magasin d'électronique.
--
--   2. La commande elle-même ne peut pas le dire : le checkout calcule
--      `order_type = supermarket si l'article est une ligne d'épicerie, sinon
--      food`. Une commande de fleurs, de cadeaux ou d'électronique est donc
--      étiquetée « food ». Même une frise par type se serait trompée.
--
-- La règle vit désormais là où vivent déjà `discount_mode` et les libellés :
-- sur la catégorie. Les trois applications la lisent au même endroit, donc
-- elles ne peuvent plus se contredire — et ouvrir une catégorie qui prépare
-- ses commandes (un traiteur, une pizzeria de plus) ne demandera pas une
-- version de chaque application, seulement un UPDATE.
--
-- Seuls les restaurants préparent. Le supermarché, la pâtisserie, le
-- fleuriste, l'animalerie, les cadeaux et l'électronique passent d'« acceptée »
-- à « prête » : le commerçant met de côté ce qu'il a déjà en rayon.
--
-- L'application se replie sur « seule la catégorie food prépare » tant que la
-- colonne n'existe pas, donc elle fonctionne avant comme après.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. État avant ──────────────────────────────────────────────────────────
SELECT id, name_fr, discount_mode, is_active
FROM public.vendor_categories
ORDER BY sort_order;


BEGIN;

ALTER TABLE public.vendor_categories
  ADD COLUMN IF NOT EXISTS has_preparation_step BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.vendor_categories.has_preparation_step IS
  'Le commerçant prépare la commande avant qu''elle soit prête (restaurants). '
  'Faux : il passe directement d''« acceptée » à « prête ».';

-- Le défaut est FALSE : une catégorie ajoutée plus tard ne prépare pas, et il
-- suffit d'un UPDATE pour lui donner l'étape. C'est le cas le plus courant.
UPDATE public.vendor_categories
   SET has_preparation_step = TRUE
 WHERE id = 'food';

UPDATE public.vendor_categories
   SET has_preparation_step = FALSE
 WHERE id IN ('grocery', 'bakery', 'flowers', 'pets', 'gifts', 'electronics');


-- ── Garde-fou avant COMMIT ─────────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.vendor_categories
   WHERE id = 'food' AND has_preparation_step;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la catégorie food devrait avoir l''étape de préparation';
  END IF;

  SELECT count(*) INTO n FROM public.vendor_categories
   WHERE id <> 'food' AND has_preparation_step;
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % catégorie(s) hors food ont l''étape de préparation', n;
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT id, name_fr, discount_mode, has_preparation_step
FROM public.vendor_categories
ORDER BY sort_order;
-- Attendu : has_preparation_step vrai pour food seulement.
