-- ============================================================================
-- CMANDILI -- Promotions, phase 1 : la base
--
-- NON EXECUTE. A relire, puis a lancer vous-meme dans le SQL Editor.
--
-- Pose la regle "quel type de remise pour quelle categorie" a un seul endroit,
-- ajoute les deux colonnes manquantes, fait expirer les promotions toutes
-- seules, et donne a l'admin le droit d'en arreter une.
--
-- AUCUNE DONNEE EXISTANTE N'EST PERDUE. Releve avant ecriture : 3 articles
-- seulement portent une remise, tous chez Texas food (categorie food), et
-- TOUS LES TROIS SONT DEJA EXPIRES :
--
--   panini        15.000 -> 8.000   fin 21/05
--   Salade Cesar   9.900 -> 7.000   fin 26/09
--   Makloub        8.000 -> 4.000   fin 27/09 01:05, quantite 5
--
-- Zero remise en grocery : faire passer le supermarche de Happy Hour a Promo
-- ne deplace donc aucune donnee.
--
-- Le mecanisme is_happy_hour / happy_hour_price / happy_hour_start/end est a
-- ZERO ligne : personne ne s'en sert. Le mecanisme vivant est
-- discount_price / discount_end_time / discount_quantity, celui qu'ecrit
-- setHappyHour et que lit le panier.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================


-- ── A. Etat avant ──────────────────────────────────────────────────────────
SELECT v.category,
       count(*) FILTER (WHERE vi.discount_price IS NOT NULL) AS articles_en_promo,
       count(*) FILTER (WHERE vi.discount_price IS NOT NULL
                          AND vi.discount_end_time > now())  AS promos_encore_actives,
       count(*)                                              AS articles_total
FROM public.vendor_items vi
JOIN public.vendors v ON v.id = vi.vendor_id
GROUP BY v.category
ORDER BY 2 DESC, 1;


BEGIN;

-- ── 1. La regle, a un seul endroit ─────────────────────────────────────────
-- Le defaut est 'percent' : une categorie ajoutee plus tard part en
-- pourcentage, et il suffit d'un UPDATE pour la basculer en Happy Hour. C'est
-- exactement ce qu'on voulait -- ajouter une categorie ne demande que de
-- renseigner cette valeur.
ALTER TABLE public.vendor_categories
  ADD COLUMN IF NOT EXISTS discount_mode text NOT NULL DEFAULT 'percent';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.vendor_categories'::regclass
       AND conname  = 'vendor_categories_discount_mode_check'
  ) THEN
    ALTER TABLE public.vendor_categories
      ADD CONSTRAINT vendor_categories_discount_mode_check
      CHECK (discount_mode IN ('happy_hour', 'percent'));
  END IF;
END
$$;

-- Restaurants et patisserie gardent le Happy Hour, le reste passe en
-- pourcentage. Les lignes absentes de vendor_categories (il n'y a pas de
-- ligne 'food' partout selon les environnements) sont creees si besoin.
UPDATE public.vendor_categories SET discount_mode = 'happy_hour'
 WHERE id IN ('food', 'bakery');

UPDATE public.vendor_categories SET discount_mode = 'percent'
 WHERE id IN ('grocery', 'flowers', 'electronics', 'gifts', 'pets');


-- ── 2. Le plafond, reglable par l'admin ────────────────────────────────────
-- 70 % par defaut. L'app partenaire le lit ici, elle ne le code pas en dur.
INSERT INTO public.global_settings (setting_key, setting_value, description)
VALUES ('max_discount_percent', '70',
        'Pourcentage de remise maximum qu''un partenaire peut appliquer a un article')
ON CONFLICT (setting_key) DO NOTHING;


-- ── 3. Les deux colonnes manquantes ────────────────────────────────────────
-- discount_price reste la source de verite du PRIX : c'est lui que lisent
-- deja le panier (CartItem.price), la commission (orders.subtotal) et le
-- client. discount_percent ne sert qu'a afficher le badge "-X%" et a
-- recalculer sans arrondi ; discount_start_time permet de programmer une
-- promotion a l'avance, ce qui est impossible aujourd'hui.
ALTER TABLE public.vendor_items
  ADD COLUMN IF NOT EXISTS discount_percent    numeric(5,2),
  ADD COLUMN IF NOT EXISTS discount_start_time timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.vendor_items'::regclass
       AND conname  = 'vendor_items_discount_percent_check'
  ) THEN
    ALTER TABLE public.vendor_items
      ADD CONSTRAINT vendor_items_discount_percent_check
      CHECK (discount_percent IS NULL OR (discount_percent > 0 AND discount_percent <= 100));
  END IF;
END
$$;

-- Une promotion dont la fin precede le debut n'a aucun sens : la base le
-- refuse, en plus du controle cote application.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.vendor_items'::regclass
       AND conname  = 'vendor_items_discount_window_check'
  ) THEN
    ALTER TABLE public.vendor_items
      ADD CONSTRAINT vendor_items_discount_window_check
      CHECK (discount_start_time IS NULL
             OR discount_end_time IS NULL
             OR discount_end_time > discount_start_time);
  END IF;
END
$$;


-- ── 4. Les promotions se terminent toutes seules ───────────────────────────
-- IL N'Y AVAIT AUCUN MECANISME. L'expiration n'etait calculee qu'a la lecture
-- (VendorItem.effectivePrice compare discount_end_time a maintenant), donc la
-- ligne gardait son discount_price indefiniment -- d'ou les 3 promos expirees
-- encore en base. Invisible pour le client, mais la page Promotions de
-- l'admin les aurait listees comme actives, et toute requete qui filtre sur
-- "discount_price IS NOT NULL" se serait trompee.
--
-- discount_end_time NULL = promotion sans fin, que le partenaire arrete
-- lui-meme : elle n'est donc jamais balayee.
SELECT cron.schedule(
  'clear_expired_promotions',
  '* * * * *',
  $job$
    UPDATE public.vendor_items
    SET    discount_price    = NULL,
           discount_percent  = NULL,
           discount_end_time = NULL,
           discount_start_time = NULL,
           discount_quantity = NULL
    WHERE  discount_end_time IS NOT NULL
      AND  discount_end_time <= now()
      AND  (discount_price IS NOT NULL OR discount_percent IS NOT NULL);
  $job$
);

-- ── 4b. Reparer disable_happy_hour ─────────────────────────────────────────
-- Il surveillait food_items.is_happy_hour : une vue qui n'expose pas cette
-- colonne (il echouait a chaque minute avant la reparation du 25/09), et un
-- mecanisme utilise par zero article. Il comparait en plus current_time en
-- UTC a une heure locale de Tunis, soit une heure d'avance. Reoriente vers la
-- table, avec le bon fuseau. Si vous preferez, ce job peut simplement etre
-- supprime -- mais tant que l'ecran Happy Hour existe pour food et bakery,
-- autant qu'il fonctionne.
SELECT cron.schedule(
  'disable_happy_hour',
  '* * * * *',
  $job$
    UPDATE public.vendor_items
    SET    is_happy_hour = false
    WHERE  is_happy_hour = true
      AND  happy_hour_end IS NOT NULL
      AND  (now() AT TIME ZONE 'Africa/Tunis')::time > happy_hour_end;
  $job$
);


-- ── 5. L'admin peut arreter n'importe quelle promotion ─────────────────────
-- vendor_items n'a aujourd'hui que deux policies : lecture ouverte, et
-- ecriture reservee au proprietaire. Un administrateur ne peut donc PAS
-- arreter la promotion d'une boutique, ce que la page Promotions demande.
--
-- Policy separee plutot qu'une condition ajoutee a celle du partenaire : les
-- policies PERMISSIVE s'additionnent, le partenaire garde exactement ses
-- droits actuels, et le droit admin se lit d'un coup d'oeil.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies
              WHERE schemaname='public' AND tablename='vendor_items'
                AND policyname='vendor_items_admin_write') THEN
    EXECUTE 'DROP POLICY vendor_items_admin_write ON public.vendor_items';
  END IF;
END
$$;

CREATE POLICY vendor_items_admin_write
  ON public.vendor_items
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles pr
             WHERE pr.id = auth.uid() AND pr.is_admin = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles pr
             WHERE pr.id = auth.uid() AND pr.is_admin = true)
  );


-- ── 6. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.vendor_categories
   WHERE id IN ('food','bakery') AND discount_mode = 'happy_hour';
  IF n < 1 THEN
    RAISE EXCEPTION 'Abandon : aucune categorie en happy_hour (food/bakery attendues)';
  END IF;

  SELECT count(*) INTO n FROM public.vendor_categories
   WHERE discount_mode = 'percent';
  IF n < 1 THEN
    RAISE EXCEPTION 'Abandon : aucune categorie en percent';
  END IF;

  SELECT count(*) INTO n FROM public.global_settings
   WHERE setting_key = 'max_discount_percent';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : max_discount_percent absent de global_settings';
  END IF;

  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema='public' AND table_name='vendor_items'
     AND column_name IN ('discount_percent','discount_start_time');
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : % colonne(s) de remise sur 2 creees', n;
  END IF;

  SELECT count(*) INTO n FROM cron.job WHERE jobname = 'clear_expired_promotions';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la tache clear_expired_promotions n''est pas planifiee';
  END IF;

  SELECT count(*) INTO n FROM pg_policies
   WHERE schemaname='public' AND tablename='vendor_items'
     AND policyname='vendor_items_admin_write';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la policy admin n''est pas posee';
  END IF;
END
$$;

COMMIT;


-- ── B. Etat apres ──────────────────────────────────────────────────────────
SELECT id           AS categorie,
       name_fr      AS libelle,
       discount_mode,
       is_active
FROM public.vendor_categories
ORDER BY discount_mode, sort_order;
-- Attendu : bakery et food en happy_hour ; grocery, flowers, pets, gifts et
-- electronics en percent.

-- Les 3 promotions expirees seront balayees par le cron a la minute suivante.
-- Pour le verifier :
-- SELECT count(*) FROM public.vendor_items WHERE discount_price IS NOT NULL;
-- -- 3 avant, 0 apres une minute.
