-- ============================================================================
-- CMANDILI — Retirer la ligne livreur « rafik2 » du compte administrateur
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
--
-- Dernier reste du compte à trois casquettes. Après la séparation du 30/09,
-- ademcherif209@gmail.com est administrateur et client ; il portait encore une
-- ligne `drivers` créée le 26/09 pour un essai, qui n'a jamais servi.
--
-- Tant qu'elle existe, ce compte apparaît dans la répartition des courses et
-- sur la carte de la flotte, et il figurerait dans n'importe quelle liste de
-- livreurs — pour un livreur qui n'existe pas.
--
--
-- ── CE QUI SERA SUPPRIMÉ : UNE SEULE LIGNE ─────────────────────────────────
--
--   drivers  aad724d0-984c-4caf-9148-40302884790f
--            user_id = be0f6629… (ademcherif209@gmail.com)
--            créée le 26/09 23:05, motorcycle, hors ligne, non bloquée
--
-- Relevé avant écriture — tout ce qui peut référencer une ligne `drivers` :
--
--   deliveries.driver_id             0   (ON DELETE CASCADE)
--   orders.driver_id                 0
--   orders.assigned_driver_id        0   (ON DELETE NO ACTION)
--   loyalty_driver_payouts.driver_id 0   (ON DELETE NO ACTION)
--   driver_payout_info (par user_id) 0
--
-- Les deux contraintes NO ACTION sont la raison de ces contrôles : une offre
-- en attente ou un versement de fidélité feraient échouer la suppression au
-- milieu de la transaction. Ici il n'y en a aucun, et les garde-fous le
-- revérifient au moment où vous lancez le fichier.
--
--
-- ── CE QUI N'EST PAS TOUCHÉ ────────────────────────────────────────────────
--
--   auth.users        l'email, le mot de passe et l'id de l'admin
--   profiles          is_admin reste true
--   orders            ses 2 commandes passées en tant que client
--   charlot@gmail.com sa boutique, son portefeuille, son relevé
--
-- À NOTER, et c'est à vous de décider : `profiles.full_name` de ce compte vaut
-- toujours « rafik2 ». C'est le nom d'affichage de votre compte
-- administrateur, hérité du même essai. Supprimer la ligne livreur ne le
-- change pas — le renommer est un UPDATE d'une ligne, dites-le si vous le
-- voulez.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================


-- ── A. Ce qui va être supprimé, relu en direct ─────────────────────────────
SELECT d.id::text        AS ligne_drivers,
       u.email           AS compte,
       pr.full_name      AS nom_affiche,
       d.vehicle_type,
       d.is_online,
       d.created_at::text AS creee_le
FROM public.drivers d
JOIN auth.users u       ON u.id = d.user_id
LEFT JOIN public.profiles pr ON pr.id = d.user_id
WHERE d.id = 'aad724d0-984c-4caf-9148-40302884790f';


BEGIN;

-- ── 1. Garde-fous AVANT la suppression ─────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  -- La ligne visée doit bien être celle du compte admin.
  SELECT count(*) INTO n FROM public.drivers
   WHERE id = 'aad724d0-984c-4caf-9148-40302884790f'
     AND user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la ligne drivers visee ne correspond plus (trouvee : %)', n;
  END IF;

  -- Aucune course, passée ou en cours.
  SELECT count(*) INTO n FROM public.deliveries
   WHERE driver_id = 'aad724d0-984c-4caf-9148-40302884790f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : ce livreur a % livraison(s)', n;
  END IF;

  SELECT count(*) INTO n FROM public.orders
   WHERE driver_id = 'aad724d0-984c-4caf-9148-40302884790f'
      OR assigned_driver_id = 'aad724d0-984c-4caf-9148-40302884790f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : ce livreur a % commande(s) ou offre(s) en cours', n;
  END IF;

  SELECT count(*) INTO n FROM public.loyalty_driver_payouts
   WHERE driver_id = 'aad724d0-984c-4caf-9148-40302884790f';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : ce livreur a % versement(s) de fidelite', n;
  END IF;

  -- Et le compte reste bien administrateur : si ce n'était plus vrai, on ne
  -- serait pas en train de nettoyer ce qu'on croit nettoyer.
  SELECT count(*) INTO n FROM public.profiles
   WHERE id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e' AND is_admin = true;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : be0f6629 n''est plus le compte administrateur';
  END IF;
END
$$;


-- ── 2. La suppression ──────────────────────────────────────────────────────
DELETE FROM public.drivers
 WHERE id = 'aad724d0-984c-4caf-9148-40302884790f'
   AND user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e';


-- ── 3. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.drivers
   WHERE user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : le compte admin porte encore % ligne(s) livreur', n;
  END IF;

  -- Le compte admin est intact : toujours administrateur, toujours ses
  -- commandes client.
  SELECT count(*) INTO n FROM public.profiles
   WHERE id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e' AND is_admin = true;
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : les droits d''administration ont ete perdus';
  END IF;

  SELECT count(*) INTO n FROM public.orders
   WHERE user_id = 'be0f6629-0f37-4112-ab8c-d717031f5d9e';
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : l''admin devrait garder ses 2 commandes client, il en a %', n;
  END IF;

  -- Aucun autre livreur n'a disparu au passage.
  SELECT count(*) INTO n FROM public.drivers;
  IF n < 1 THEN
    RAISE EXCEPTION 'Abandon : plus aucun livreur en base';
  END IF;
END
$$;

COMMIT;


-- ── B. État après ──────────────────────────────────────────────────────────
SELECT u.email,
       (SELECT count(*) FROM public.drivers  d  WHERE d.user_id  = u.id) AS lignes_livreur,
       (SELECT count(*) FROM public.partners p  WHERE p.user_id  = u.id) AS lignes_partenaire,
       (SELECT count(*) FROM public.orders   o  WHERE o.user_id  = u.id) AS commandes_client,
       (SELECT pr.is_admin FROM public.profiles pr WHERE pr.id = u.id)   AS administrateur
FROM auth.users u
WHERE u.email IN ('ademcherif209@gmail.com', 'charlot@gmail.com')
ORDER BY u.email;
-- Attendu : l'admin 0 livreur, 0 partenaire, 2 commandes, administrateur =
--           true ; charlot@gmail.com 0 livreur, 1 partenaire.
