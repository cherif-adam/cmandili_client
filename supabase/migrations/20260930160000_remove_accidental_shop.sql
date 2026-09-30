-- ============================================================================
-- CMANDILI — Supprimer la boutique créée par accident le 30/09 à 00:00
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- ── CE QUI S'EST PASSÉ ─────────────────────────────────────────────────────
--
--   23:57:39  le script de séparation crée charlot@gmail.com et lui transfère
--             la boutique, son portefeuille et son relevé. Le compte admin
--             perd sa ligne `partners` — c'était le but.
--   00:00:20  l'app partenaire, toujours connectée avec la session admin
--             conservée par `flutter run`, trouve un utilisateur connecté SANS
--             ligne partners. Elle en conclut « nouveau partenaire » et ouvre
--             l'écran de configuration, qui crée une boutique.
--
-- La séparation, elle, a parfaitement fonctionné :
--
--   charlot@gmail.com   partners 1, wallets 1 (50.000 DT), settlements 1
--                       boutique 134dd418 « Charlot », owner_id = charlot
--   admin               wallets 0, settlements 0
--
-- Le nom est d'ailleurs bien arrivé côté client : `vendors.name` vaut
-- « Charlot », le trigger de synchronisation est en place.
--
--
-- ── CE QUI SERA SUPPRIMÉ : EXACTEMENT DEUX LIGNES ──────────────────────────
--
--   partners  ebb887d6-5765-4f33-84f6-e805d12c4937
--             user_id = be0f6629… (admin), business_name 'charlot',
--             entity_id = 17966cd4…, créée le 30/09 à 00:00:20
--
--   vendors   17966cd4-5a68-438c-a530-ba1c6d903c3f
--             name 'charlot' (minuscule), category 'food',
--             créée le 30/09 à 00:00:20
--
-- Relevé avant écriture : cette boutique porte 0 article et 0 commande. Rien
-- d'autre ne la référence.
--
-- NE SONT PAS TOUCHÉS : la vraie boutique 134dd418 « Charlot », son
-- portefeuille de 50.000 DT, son relevé, le compte charlot@gmail.com, le
-- compte admin (email, mot de passe, droits, 2 commandes client, ligne
-- livreur « rafik2 »).
--
-- Les garde-fous refusent de continuer si l'un de ces faits n'est plus vrai :
-- la boutique ne doit avoir ni article ni commande, appartenir à l'admin, et
-- ne surtout pas être 134dd418.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. Ce qui va être supprimé, relu en direct ─────────────────────────────
SELECT 'partners' AS table_cible, p.id::text AS ligne, p.business_name AS nom,
       u.email AS proprietaire, p.created_at::text AS creee_le
FROM public.partners p
JOIN auth.users u ON u.id = p.user_id
WHERE p.id = 'ebb887d6-5765-4f33-84f6-e805d12c4937'
UNION ALL
SELECT 'vendors', v.id::text, v.name, '—', v.created_at::text
FROM public.vendors v
WHERE v.id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';


BEGIN;

-- ── 1. Garde-fous AVANT toute suppression ──────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  -- Jamais la vraie boutique.
  IF '17966cd4-5a68-438c-a530-ba1c6d903c3f' = '134dd418-d329-49d9-88ad-45d33741f44d' THEN
    RAISE EXCEPTION 'Abandon : la cible est la vraie boutique';
  END IF;

  -- La boutique visée doit être vide. Un article ou une commande voudrait
  -- dire qu'elle a servi, et qu'elle n'est donc pas l'accident.
  SELECT count(*) INTO n FROM public.vendor_items
   WHERE vendor_id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : la boutique porte % article(s)', n;
  END IF;

  SELECT count(*) INTO n FROM public.orders
   WHERE restaurant_id = '17966cd4-5a68-438c-a530-ba1c6d903c3f'
      OR supermarket_id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : la boutique porte % commande(s)', n;
  END IF;

  -- La ligne partners visée doit bien être celle de l'admin et pointer sur
  -- cette boutique-là.
  SELECT count(*) INTO n FROM public.partners
   WHERE id = 'ebb887d6-5765-4f33-84f6-e805d12c4937'
     AND user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e'
     AND entity_id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la ligne partners visee ne correspond plus (trouvee : %)', n;
  END IF;

  -- La vraie boutique doit être chez charlot@gmail.com AVANT qu'on touche à
  -- quoi que ce soit : si la séparation avait été défaite, supprimer ici
  -- laisserait le partenaire sans boutique du tout.
  SELECT count(*) INTO n FROM public.partners p
    JOIN auth.users u ON u.id = p.user_id
   WHERE p.entity_id = '134dd418-d329-49d9-88ad-45d33741f44d'
     AND u.email = 'charlot@gmail.com';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la vraie boutique n''est pas chez charlot@gmail.com';
  END IF;
END
$$;


-- ── 2. Les deux suppressions ───────────────────────────────────────────────
-- `partners` d'abord : elle référence `vendors` par entity_id.
DELETE FROM public.partners
 WHERE id = 'ebb887d6-5765-4f33-84f6-e805d12c4937'
   AND user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e'
   AND entity_id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';

DELETE FROM public.vendors
 WHERE id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';


-- ── 3. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.vendors
   WHERE id = '17966cd4-5a68-438c-a530-ba1c6d903c3f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : la boutique accidentelle existe encore';
  END IF;

  -- La vraie boutique est intacte, chez son partenaire, avec son solde.
  SELECT count(*) INTO n FROM public.partners p
    JOIN auth.users u ON u.id = p.user_id
    JOIN public.vendors v ON v.id = p.entity_id
    JOIN public.wallets w ON w.user_id = p.user_id
   WHERE v.id = '134dd418-d329-49d9-88ad-45d33741f44d'
     AND u.email = 'charlot@gmail.com'
     AND w.balance = 50.000;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la vraie boutique, son proprietaire ou son solde ont bouge';
  END IF;

  -- L'admin n'a plus de boutique, et c'est ce qu'on veut.
  SELECT count(*) INTO n FROM public.partners
   WHERE user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : le compte admin porte encore % boutique(s)', n;
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT u.email,
       p.business_name,
       v.name       AS nom_cote_client,
       w.balance::text AS solde
FROM auth.users u
LEFT JOIN public.partners p ON p.user_id = u.id
LEFT JOIN public.vendors  v ON v.id = p.entity_id
LEFT JOIN public.wallets  w ON w.user_id = u.id
WHERE u.email IN ('ademcherif209@gmail.com', 'charlot@gmail.com')
ORDER BY u.email;
-- Attendu : admin sans boutique et sans solde ; charlot@gmail.com avec
--           « Charlot » des deux côtés et 50.000 DT.
