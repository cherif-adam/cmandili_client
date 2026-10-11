-- ============================================================================
-- CMANDILI — Retrait de la majoration de 10 % sur le prix des articles
--
-- Modèle visé : le prix saisi par le commerçant est exactement celui que le
-- client voit et paie. La commission partenaire (10 % par défaut) est ensuite
-- prélevée sur ce montant réel. Les frais de livraison ne changent pas.
--
-- POURQUOI CETTE FORME.
--   `apply_promo_code` a été modifiée plusieurs fois, et la version en
--   production ne correspond pas au fichier de migration d'origine : la
--   déclaration y tient en une espace au lieu de trois, elle est à la ligne 8
--   au lieu de 110, et les commentaires qui décrivaient la majoration en ont
--   disparu. Recopier un ancien fichier écraserait donc des corrections.
--   Cette migration lit la définition RÉELLEMENT EN PRODUCTION
--   (pg_get_functiondef), y retire la majoration, et recrée la fonction.
--   Tout le reste du corps est conservé au caractère près.
--
-- CE QU'ELLE CHANGE, ET RIEN D'AUTRE.
--   1. la déclaration   c_markup CONSTANT NUMERIC := 1.10;   → supprimée
--   2. son unique usage  ... + v_addons) * c_markup, 3)      → ... + v_addons), 3)
--
--   Aucun ancrage sur les fins de ligne : la version précédente de cette
--   migration échouait parce qu'elle exigeait un saut de ligne juste après le
--   point-virgule. Les classes de caractères ci-dessous tolèrent espaces,
--   tabulations et retours chariot. La déclaration retirée laisse une ligne
--   vide dans le bloc DECLARE, ce qui est sans effet.
--
-- SÉCURITÉ.
--   Échoue bruyamment, sans rien modifier, si : la fonction est absente,
--   plusieurs surcharges portent la majoration, une substitution ne s'applique
--   pas, ou une référence subsiste. En cas d'échec, le message liste les
--   lignes fautives pour éviter un aller-retour de plus.
--   Rejouable : si la majoration est déjà partie, elle le signale et s'arrête.
--
-- NE MODIFIE PAS : generate_settlements_on_delivery, apply_loyalty_at_checkout,
--   les frais de livraison, les commandes et les portefeuilles existants.
-- ============================================================================

DO $migration$
DECLARE
  v_oid        oid;
  v_nb         int;
  v_def        text;
  v_apres_use  text;
  v_final      text;
  v_restant    text;
BEGIN
  -- ── 1. Trouver LA surcharge qui porte la majoration ───────────────────
  SELECT count(*) INTO v_nb
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname  = 'apply_promo_code'
     AND pg_get_functiondef(p.oid) LIKE '%c_markup%';

  IF v_nb = 0 THEN
    RAISE NOTICE 'Aucune surcharge de apply_promo_code ne contient c_markup — rien à faire.';
    RETURN;
  END IF;

  IF v_nb > 1 THEN
    RAISE EXCEPTION
      '% surcharges de apply_promo_code contiennent c_markup. Traitement manuel requis — rien n''a été modifié.', v_nb;
  END IF;

  SELECT p.oid, pg_get_functiondef(p.oid)
    INTO v_oid, v_def
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname  = 'apply_promo_code'
     AND pg_get_functiondef(p.oid) LIKE '%c_markup%';

  -- ── 2. Retirer l'usage : « * c_markup » dans le ROUND(...) ────────────
  --     On ne touche ni à la virgule ni à la parenthèse qui suivent.
  v_apres_use := regexp_replace(v_def, '[ \t\r]*\*[ \t\r]*c_markup', '', 'g');

  IF v_apres_use = v_def THEN
    RAISE EXCEPTION
      'L''usage « * c_markup » est introuvable dans la définition de production. Rien n''a été modifié.';
  END IF;

  -- ── 3. Retirer la déclaration, sans exiger de saut de ligne ───────────
  v_final := regexp_replace(
               v_apres_use,
               '[ \t\r]*c_markup[ \t\r]+CONSTANT[ \t\r]+NUMERIC[ \t\r]*:=[ \t\r]*1\.10[ \t\r]*;',
               '',
               'g');

  IF v_final = v_apres_use THEN
    RAISE EXCEPTION
      'La déclaration de c_markup est introuvable. Rien n''a été modifié.';
  END IF;

  -- ── 4. Plus aucune trace ? ────────────────────────────────────────────
  IF position('c_markup' in v_final) <> 0 THEN
    SELECT string_agg(format('ligne %s : %s', n, l), E'\n')
      INTO v_restant
      FROM unnest(string_to_array(v_final, E'\n')) WITH ORDINALITY AS t(l, n)
     WHERE t.l LIKE '%c_markup%';

    RAISE EXCEPTION
      E'Il reste une référence à c_markup après substitution :\n%\nRien n''a été modifié.', v_restant;
  END IF;

  -- ── 5. Recréer la fonction ────────────────────────────────────────────
  EXECUTE v_final;

  -- ── 6. Relire le catalogue : la preuve, pas la promesse ───────────────
  IF pg_get_functiondef(v_oid) LIKE '%c_markup%' THEN
    RAISE EXCEPTION
      'La fonction recréée contient encore c_markup — incohérence inattendue.';
  END IF;

  RAISE NOTICE 'apply_promo_code : majoration de 10 %% retirée. Le sous-total est désormais calculé aux prix du commerçant.';
END
$migration$;


-- ============================================================================
-- VÉRIFICATION APRÈS EXÉCUTION — à lancer séparément, lecture seule.
--
--   SELECT position('c_markup'   in pg_get_functiondef(p.oid)) AS doit_etre_0,
--          position('v_eligible' in pg_get_functiondef(p.oid)) > 0 AS corps_intact,
--          position('first_order_only' in pg_get_functiondef(p.oid)) > 0 AS regle_1re_cmd
--     FROM pg_proc p
--     JOIN pg_namespace ns ON ns.oid = p.pronamespace
--    WHERE ns.nspname = 'public' AND p.proname = 'apply_promo_code';
--
-- Attendu : doit_etre_0 = 0, corps_intact = true, regle_1re_cmd = true
-- ============================================================================
