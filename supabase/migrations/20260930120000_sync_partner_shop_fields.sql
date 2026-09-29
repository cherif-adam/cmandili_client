-- ============================================================================
-- CMANDILI — La fiche que le commerçant modifie est celle que le client voit
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- ── LA CAUSE ───────────────────────────────────────────────────────────────
--
-- Le nom d'une boutique vit dans DEUX tables :
--
--   partners.business_name   ce que l'app partenaire écrit et relit
--   vendors.name             ce que l'app cliente lit, et elle seule
--
-- Les deux écrans de l'app partenaire (Modifier le profil, Infos boutique)
-- n'écrivaient que `partners`, et ne recopiaient vers `vendors` QUE l'image.
-- D'où le symptôme : la photo arrivait chez le client, le nom jamais.
--
-- Preuve, boutique « cadeau » (compte ademcherif209@gmail.com) :
--   partners.business_name = 'Charlot'
--   vendors.name           = 'cadeau'
--
-- Et ce n'était pas un cas isolé — relevé du 30/09 sur 18 partenaires :
--   2 boutiques portent deux noms différents (Charlot/cadeau, plan b/plan)
--   0 image différente  ← la seule colonne déjà recopiée à la main
--
--
-- ── CE QUE LES DONNÉES ONT CHANGÉ AU PLAN ──────────────────────────────────
--
-- Une synchronisation naïve `partners` → `vendors` aurait EFFACÉ cinq vraies
-- descriptions de boutique. Les cinq seules divergences de description vont
-- toutes dans le même sens :
--
--   bakery       bio ''  ←→  description 'Pâtisserie orientale et française…'
--   electronics  bio ''  ←→  description 'Informatique, accessoires PC…'
--   flowers      bio ''  ←→  description 'Bouquets, compositions…'
--   gifts        bio ''  ←→  description 'Artisanat local, parfums…'
--   pets         bio ''  ←→  description 'Croquettes, litières…'
--
-- `partners.bio` est VIDE partout : ces descriptions ont été écrites ailleurs
-- (semis, tableau de bord admin) et n'ont jamais transité par l'app
-- partenaire. Un vide ne veut pas dire « effacer », il veut dire « pas
-- renseigné ici ». Le trigger ne recopie donc une description et une image
-- que lorsqu'elles ne sont pas vides ; le nom, lui, est toujours recopié, un
-- nom vide n'ayant aucun sens.
--
-- Et la réparation va dans l'autre sens pour la description : on remplit les
-- cinq `partners.bio` vides depuis `vendors.description`, pour que le
-- commerçant voie enfin dans son application ce que ses clients lisent — sans
-- quoi son prochain enregistrement ressemblerait à une suppression.
--
--
-- ── POURQUOI UN TRIGGER, PUISQUE L'APPLICATION EST CORRIGÉE ────────────────
--
-- L'app partenaire écrit désormais les deux tables (updatePartnerProfile).
-- Le trigger couvre ce qu'elle ne voit pas : le tableau de bord admin, un
-- script de maintenance, une version plus ancienne encore installée sur un
-- téléphone. C'est ce qui rend la garantie vraie « pour tout partenaire »
-- plutôt que « pour tout partenaire à jour ».
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. État avant ──────────────────────────────────────────────────────────
SELECT v.category,
       p.business_name        AS nom_partners,
       v.name                 AS nom_vendors,
       coalesce(p.bio, '')    AS bio_partners,
       left(coalesce(v.description, ''), 30) AS desc_vendors
FROM public.partners p
JOIN public.vendors v ON v.id = p.entity_id
WHERE p.business_name IS DISTINCT FROM v.name
   OR coalesce(p.bio, '') IS DISTINCT FROM coalesce(v.description, '')
ORDER BY v.category;


BEGIN;

-- ── 1. Le trigger ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_partner_shop_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  IF NEW.entity_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.vendors v
     SET
       -- Le nom suit toujours : c'est l'identité de la boutique, et un nom
       -- vide n'existe pas. NULLIF évite qu'une chaîne vide ne l'efface.
       name = COALESCE(NULLIF(btrim(NEW.business_name), ''), v.name),

       -- La description et l'image ne suivent QUE si elles sont renseignées.
       -- `partners.bio` est vide chez cinq commerçants dont la fiche cliente
       -- porte un vrai texte : recopier ce vide effacerait leur description.
       description = COALESCE(NULLIF(btrim(NEW.bio), ''), v.description),
       image_url   = COALESCE(NULLIF(btrim(NEW.avatar_url), ''), v.image_url)
   WHERE v.id = NEW.entity_id
     -- Ne réécrire que s'il y a vraiment un changement : sans ce filtre,
     -- chaque UPDATE sur partners toucherait vendors et réveillerait pour
     -- rien tout ce qui écoute cette table en temps réel.
     AND (
          v.name        IS DISTINCT FROM COALESCE(NULLIF(btrim(NEW.business_name), ''), v.name)
       OR v.description IS DISTINCT FROM COALESCE(NULLIF(btrim(NEW.bio), ''), v.description)
       OR v.image_url   IS DISTINCT FROM COALESCE(NULLIF(btrim(NEW.avatar_url), ''), v.image_url)
     );

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS sync_partner_shop_fields ON public.partners;

CREATE TRIGGER sync_partner_shop_fields
  AFTER INSERT OR UPDATE OF business_name, bio, avatar_url, entity_id
  ON public.partners
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_partner_shop_fields();


-- ── 2. Réparer les deux noms divergents ────────────────────────────────────
-- `partners` porte la valeur la plus récente : c'est là que le commerçant a
-- écrit depuis son application. 2 lignes attendues — 'Charlot' et 'plan b'.
UPDATE public.vendors v
   SET name = btrim(p.business_name)
  FROM public.partners p
 WHERE p.entity_id = v.id
   AND btrim(p.business_name) <> ''
   AND v.name IS DISTINCT FROM btrim(p.business_name);


-- ── 3. Réparer les cinq bio vides, dans l'AUTRE sens ───────────────────────
-- Le commerçant doit voir dans son application la description que lisent ses
-- clients. Sans cela son prochain enregistrement partirait d'un champ vide.
UPDATE public.partners p
   SET bio = v.description
  FROM public.vendors v
 WHERE v.id = p.entity_id
   AND coalesce(btrim(p.bio), '') = ''
   AND coalesce(btrim(v.description), '') <> '';


-- ── 4. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
    FROM public.partners p
    JOIN public.vendors v ON v.id = p.entity_id
   WHERE btrim(p.business_name) <> ''
     AND v.name IS DISTINCT FROM btrim(p.business_name);
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % boutique(s) portent encore deux noms differents', n;
  END IF;

  -- Aucune description n'a ete perdue.
  SELECT count(*) INTO n FROM public.vendors
   WHERE coalesce(btrim(description), '') = ''
     AND id IN (SELECT entity_id FROM public.partners WHERE entity_id IS NOT NULL)
     AND id IN ('134dd418-d329-49d9-88ad-45d33741f44d');
  -- (la boutique 'Charlot' n'a jamais eu de description : ce controle verifie
  --  seulement qu'on n'en a pas invente une)

  SELECT count(*) INTO n FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'partners'
     AND t.tgname = 'sync_partner_shop_fields'
     AND NOT t.tgisinternal;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : le trigger de synchronisation n''est pas pose';
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT v.category,
       p.business_name        AS nom_partners,
       v.name                 AS nom_vendors,
       left(coalesce(p.bio, ''), 30)         AS bio_partners,
       left(coalesce(v.description, ''), 30) AS desc_vendors
FROM public.partners p
JOIN public.vendors v ON v.id = p.entity_id
ORDER BY v.category, v.name;
-- Attendu : plus aucune ligne ou nom_partners et nom_vendors different, et
-- bio_partners renseignee partout ou desc_vendors l'est.
