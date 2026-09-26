-- ============================================================================
-- CMANDILI -- Supprimer des comptes livreurs de test
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- ── LA LISTE ───────────────────────────────────────────────────────────────
-- Trois comptes seulement. `drive@test.com` N'EXISTE PAS avec cette
-- orthographe : les deux adresses proches sont `drive@gmail.com` (nom
-- "drive", solde 249.391) et `driver@test.com` (nom "driver"). Conformement
-- a la consigne, rien n'est fait pour ce quatrieme tant que vous n'avez pas
-- tranche -- ajoutez-le dans _targets ci-dessous si besoin, le garde-fou
-- s'adapte tout seul au nombre d'adresses listees.
--
--   adem1@gmail.com     user e24c65e6…  nom "adem"   solde 298.850  active
--   firas123@gmail.com  user 6cee3137…  nom "firas"  solde   0.000  blocked
--   adam@gmail.com      user 57640370…  nom "adam"   solde  98.850  active
--
-- ── CE QUI SERA SUPPRIME, PAR COMPTE ───────────────────────────────────────
--                        adem1   firas123   adam
--   drivers                 1        1        1
--   profiles                1        1        1
--   wallets                 1        1        1
--   settlements             1        0        1
--   notifications           2        1        2
--   device_tokens           1        1        1
--   auth.users              1        1        1
--
-- AUCUNE COMMANDE, ni comme livreur ni comme client, pour aucun des trois
-- (verifie sur orders.driver_id, orders.assigned_driver_id et orders.user_id).
-- La question "garder les commandes avec driver_id NULL ou les supprimer" ne
-- se pose donc pas ici. A savoir tout de meme pour une prochaine fois :
--   * orders.user_id est en ON DELETE CASCADE vers auth.users -- supprimer un
--     compte qui a commande EFFACERAIT ses commandes. Il faudrait alors
--     extraire ces comptes de la liste et en parler d'abord.
--   * orders.driver_id n'a AUCUNE contrainte de cle etrangere : supprimer un
--     livreur qui a des courses laisserait des driver_id orphelins plutot que
--     d'echouer. Rien ne protege, il faut verifier a la main -- ce qui est
--     fait par le garde-fou de l'etape 1.
--   * deliveries.driver_id est en CASCADE : les lignes de suivi partiraient
--     avec le livreur.
--
-- ── POURQUOI UN SEUL DELETE SUFFIT ─────────────────────────────────────────
-- 35 contraintes pointent vers auth.users, et toutes celles qui concernent
-- ces comptes sont en ON DELETE CASCADE : drivers, profiles, wallets,
-- settlements, notifications, device_tokens, plus tout le schema auth
-- (identities, sessions, one_time_tokens, mfa_factors…). Un DELETE sur
-- auth.users emporte donc proprement le reste.
--
-- Les deux seules contraintes en NO ACTION qui pourraient bloquer sont
-- public.payments et loyalty_driver_payouts.customer_id : verifie, 0 ligne
-- pour les trois comptes.
--
-- ── SQL OU API ADMIN ? ─────────────────────────────────────────────────────
-- L'API admin (auth.admin.deleteUser) est la voie documentee par Supabase et
-- fonctionne tout aussi bien. Le SQL est prefere ici pour UNE raison : il est
-- transactionnel. Le garde-fou de l'etape 3 peut donc tout annuler si le
-- compte n'est pas exactement ce qui etait prevu, ce que trois appels HTTP
-- successifs ne permettent pas -- ils laisseraient un etat a moitie supprime.
--
-- NOTE SUR L'AFFICHAGE : `supabase db query --file` ne renvoie que le
-- resultat de la DERNIERE instruction. Lancez la section A seule d'abord si
-- vous voulez voir la sauvegarde, puis le reste.
-- ============================================================================


-- ── A. Sauvegarde : tout ce qui va disparaitre ─────────────────────────────
-- A lancer SEUL et a conserver avant d'executer la suite.
SELECT u.email,
       u.id                               AS user_id,
       COALESCE(p.full_name, '—')         AS nom,
       u.created_at                       AS compte_cree,
       u.last_sign_in_at,
       d.id                               AS driver_id,
       d.is_online, d.is_blocked,
       d.current_lat, d.current_lng, d.last_location_update,
       w.balance, w.status                AS wallet_status,
       (SELECT count(*) FROM public.settlements s   WHERE s.user_id = u.id) AS n_settlements,
       (SELECT count(*) FROM public.notifications n WHERE n.user_id = u.id) AS n_notifications,
       (SELECT count(*) FROM public.device_tokens t WHERE t.user_id = u.id) AS n_device_tokens
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.drivers  d ON d.user_id = u.id
LEFT JOIN public.wallets  w ON w.user_id = u.id
WHERE u.email IN ('adem1@gmail.com', 'firas123@gmail.com', 'adam@gmail.com')
ORDER BY u.email;


BEGIN;

-- ── 1. La liste, et rien d'autre ───────────────────────────────────────────
-- Seul endroit a modifier pour ajouter ou retirer un compte.
CREATE TEMP TABLE _targets(email text PRIMARY KEY) ON COMMIT DROP;
INSERT INTO _targets(email) VALUES
  ('adem1@gmail.com'),
  ('firas123@gmail.com'),
  ('adam@gmail.com');
  -- ('drive@gmail.com')  <- a decommenter SEULEMENT apres votre confirmation

-- Refus de demarrer si la realite ne correspond pas a la liste.
DO $$
DECLARE n_listes integer; n_trouves integer; n_bloquants integer;
BEGIN
  SELECT count(*) INTO n_listes FROM _targets;

  SELECT count(*) INTO n_trouves
  FROM auth.users u JOIN _targets t ON t.email = u.email;
  IF n_trouves <> n_listes THEN
    RAISE EXCEPTION 'Abandon : % adresse(s) listee(s), % trouvee(s) en base. Verifiez l''orthographe exacte.',
      n_listes, n_trouves;
  END IF;

  -- Aucune commande rattachee, dans un sens comme dans l'autre.
  SELECT count(*) INTO n_bloquants
  FROM public.orders o
  WHERE o.user_id IN (SELECT u.id FROM auth.users u JOIN _targets t ON t.email = u.email)
     OR o.driver_id IN (SELECT d.id FROM public.drivers d
                        JOIN auth.users u ON u.id = d.user_id
                        JOIN _targets t ON t.email = u.email)
     OR o.assigned_driver_id IN (SELECT d.id FROM public.drivers d
                                 JOIN auth.users u ON u.id = d.user_id
                                 JOIN _targets t ON t.email = u.email);
  IF n_bloquants <> 0 THEN
    RAISE EXCEPTION 'Abandon : % commande(s) rattachee(s) a ces comptes. Parlez-en avant de supprimer.', n_bloquants;
  END IF;

  -- Les deux contraintes NO ACTION qui feraient echouer le DELETE.
  SELECT count(*) INTO n_bloquants
  FROM public.payments pay
  WHERE pay.user_id IN (SELECT u.id FROM auth.users u JOIN _targets t ON t.email = u.email);
  IF n_bloquants <> 0 THEN
    RAISE EXCEPTION 'Abandon : % paiement(s) rattache(s) (contrainte NO ACTION).', n_bloquants;
  END IF;
END
$$;


-- ── 2. La suppression ──────────────────────────────────────────────────────
-- Un seul DELETE : les CASCADE emportent drivers, profiles, wallets,
-- settlements, notifications, device_tokens et tout le schema auth.
WITH supprimes AS (
  DELETE FROM auth.users u
   USING _targets t
   WHERE u.email = t.email
  RETURNING u.id
)
SELECT count(*) AS n_supprimes INTO TEMP TABLE _resultat FROM supprimes;


-- ── 3. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n_supprimes integer; n_listes integer; n_restants integer;
BEGIN
  SELECT n_supprimes INTO n_supprimes FROM _resultat;
  SELECT count(*) INTO n_listes FROM _targets;

  IF n_supprimes <> n_listes THEN
    RAISE EXCEPTION 'Abandon : % compte(s) supprime(s), % attendu(s).', n_supprimes, n_listes;
  END IF;

  -- Et plus aucune trace des adresses listees.
  SELECT count(*) INTO n_restants
  FROM auth.users u JOIN _targets t ON t.email = u.email;
  IF n_restants <> 0 THEN
    RAISE EXCEPTION 'Abandon : % compte(s) subsiste(nt).', n_restants;
  END IF;

  RAISE NOTICE '% compte(s) supprime(s).', n_supprimes;
END
$$;

DROP TABLE _resultat;

COMMIT;


-- ── 4. Les livreurs restants ───────────────────────────────────────────────
SELECT u.email,
       COALESCE(p.full_name, '(sans nom)') AS nom,
       d.is_online,
       d.is_blocked,
       COALESCE(w.balance::text, '—')      AS solde,
       COALESCE(w.status, '—')             AS wallet
FROM public.drivers d
JOIN auth.users u           ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
LEFT JOIN public.wallets  w ON w.user_id = d.user_id
ORDER BY COALESCE(p.full_name, ''), u.email;


-- ── 5. Controle des doublons de nom ────────────────────────────────────────
-- Attendu : aucune ligne. Verifie avant ecriture de ce fichier, les noms des
-- livreurs restants sont tous distincts.
SELECT COALESCE(p.full_name, '(sans nom)') AS nom,
       count(*)                            AS n,
       string_agg(u.email, ', ' ORDER BY u.email) AS comptes
FROM public.drivers d
JOIN auth.users u           ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
GROUP BY 1
HAVING count(*) > 1
ORDER BY 2 DESC;
