-- ============================================================================
-- CMANDILI -- Blocage fantome des livreurs, et "en ligne" perime
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- Version 2. La v1 corrigeait la cause du mauvais cote et ajoutait un "filet"
-- dans enforce_prepaid_block. Ce filet etait dangereux : sur un
-- INSERT ... ON CONFLICT, le passage BEFORE INSERT voit la ligne PROPOSEE,
-- dont status vaut le defaut 'active' et blocked_reason NULL, quelle que soit
-- la ligne existante. Le filet aurait donc debloque un compte bloque a la
-- main, et la notification "Solde epuise" partait deux fois, une par passage.
-- enforce_prepaid_block n'est plus touchee du tout ici.
--
--
-- ── PROBLEME 1 : ce qui remet drivers.is_blocked a TRUE ────────────────────
--
-- Une seule fonction ecrit ce drapeau : enforce_prepaid_block, BEFORE INSERT
-- OR UPDATE ON wallets. Ni cron, ni Edge Function, ni les apps, ni l'admin
-- (aucune trace dans audit_logs).
--
-- update_wallet_balance, AFTER INSERT sur settlements, fait :
--
--     INSERT INTO public.wallets (user_id, balance)
--     VALUES (NEW.user_id, NEW.amount)          <-- le MONTANT, pas le solde
--     ON CONFLICT (user_id) DO UPDATE SET balance = wallets.balance + NEW.amount;
--
-- Sur un portefeuille existant, Postgres declenche le BEFORE INSERT AVANT de
-- detecter le conflit : enforce_prepaid_block voit balance = -1.734 pour une
-- commission, juge le compte a sec et bloque le livreur. Le conflit resout
-- ensuite en UPDATE avec le vrai solde, mais la branche de deblocage ne
-- s'execute que si le portefeuille est lui-meme 'blocked' -- or il est
-- 'active'. Le drapeau reste a TRUE.
--
-- D'ou l'etat impossible : livreur bloque, portefeuille 'active',
-- blocked_reason NULL, solde positif, aucune trace d'audit. Et cela recommence
-- a CHAQUE commande livree, ce qui explique pourquoi le nettoyage ne tenait
-- pas.
--
-- LA CORRECTION : faire l'UPDATE d'abord, et n'INSERER que si aucune ligne
-- n'a ete touchee. Le passage BEFORE INSERT ne se produit plus que pour un
-- portefeuille reellement neuf -- cas ou balance = amount est la bonne valeur.
-- Le ON CONFLICT reste sur l'INSERT comme garde-fou de concurrence.
--
--
-- ── PROBLEME 2 : "en ligne" sans l'etre ────────────────────────────────────
--
-- next_eligible_driver ne verifie ni la fraicheur de la position, ni
-- is_blocked. Releve avant ecriture :
--
--     driver@test.com   position vieille de 3250 min (54 h)  -> eligible
--     drive@gmail.com   position vieille de  324 min         -> eligible
--     adem@gmail.com    position vieille de  279 min         -> eligible, et bloque
--
-- Les trois pouvaient recevoir une offre. Chaque fantome coute une minute de
-- retard au client, le temps que rotate_expired_offers passe au suivant.
--
--
-- ── PREUVE (transaction annulee, correctif applique dedans) ────────────────
--
--   (a) sain + commission           is_blocked=f  solde=50.934   wallet=active
--   (b) bloque manuel + commission  is_blocked=t  solde=247.657  wallet=blocked  raison=manual
--   (c) sous le plancher            is_blocked=t  solde=-101.150 wallet=blocked  raison=balance
--       notifications "solde epuise" envoyees : 1
--
-- (a) valait is_blocked=t avant le correctif. (b) et (c) confirment que rien
-- d'autre n'a bouge : blocage manuel preserve, blocage legitime toujours pose,
-- une seule notification. Verifie apres coup : aucun settlement de preuve
-- subsistant, et la fonction revenue a sa version d'origine (le DDL est
-- transactionnel).
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================


-- ── A. Etat avant ──────────────────────────────────────────────────────────
SELECT u.email, COALESCE(p.full_name,'—') AS nom, d.is_online, d.is_blocked,
       ROUND(EXTRACT(EPOCH FROM (now() - d.last_location_update))/60) AS position_min,
       w.balance, w.status AS wallet, COALESCE(w.blocked_reason,'—') AS raison
FROM public.drivers d
JOIN auth.users u           ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
LEFT JOIN public.wallets  w ON w.user_id = d.user_id
ORDER BY d.is_online DESC, d.last_location_update NULLS FIRST;


BEGIN;

-- ── 1. La cause : UPDATE d'abord, INSERT seulement si rien n'a bouge ───────
CREATE OR REPLACE FUNCTION public.update_wallet_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_touched integer;
BEGIN
  -- Le chemin normal : le portefeuille existe, on l'ajuste. Seul le passage
  -- BEFORE UPDATE se declenche, avec le solde reel.
  UPDATE public.wallets
     SET balance = balance + NEW.amount,
         updated_at = now()
   WHERE user_id = NEW.user_id;

  GET DIAGNOSTICS v_touched = ROW_COUNT;

  -- Portefeuille reellement neuf. Ici balance = amount est la bonne valeur,
  -- donc le passage BEFORE INSERT juge la bonne chose. Le ON CONFLICT couvre
  -- la course entre deux commissions simultanees sur un meme compte neuf.
  IF v_touched = 0 THEN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (NEW.user_id, NEW.amount)
    ON CONFLICT (user_id)
    DO UPDATE SET balance = public.wallets.balance + NEW.amount,
                  updated_at = now();
  END IF;

  RETURN NEW;
END;
$$;

-- enforce_prepaid_block n'est PAS modifiee : une fois la cause corrigee, sa
-- logique d'origine est juste. Toute "amelioration" a cet endroit risque de
-- marcher sur les blocages manuels, comme la v1 de ce script le faisait.


-- ── 2. Remettre d'aplomb les drapeaux deja fausses ─────────────────────────
-- Solde strictement positif ET portefeuille 'active' : un livreur reellement
-- a sec, ou bloque a la main, n'est pas touche.
UPDATE public.drivers d
SET    is_blocked = false
FROM   public.wallets w
WHERE  w.user_id = d.user_id
  AND  d.is_blocked = true
  AND  w.balance > 0
  AND  w.status = 'active';


-- ── 3. Le dispatch refuse un livreur bloque ou a la position perimee ───────
-- Corps repris a l'identique de la version en base, avec DEUX lignes
-- ajoutees, signalees en commentaire. Le reste -- rayon, deja-passes,
-- livraison en cours, offre en attente, tri par distance -- est inchange.
--
-- Cette condition est la vraie garantie : elle s'applique au moment du choix
-- et ne depend d'aucune tache planifiee.
CREATE OR REPLACE FUNCTION public.next_eligible_driver(
  p_order_id uuid,
  p_radius_km double precision DEFAULT 7
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lat       DOUBLE PRECISION;
  v_lng       DOUBLE PRECISION;
  v_passed    UUID[];
  v_driver_id UUID;
BEGIN
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION),
    o.passed_driver_ids
  INTO v_lat, v_lng, v_passed
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
    RETURN NULL;
  END IF;

  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.is_online      = TRUE
    -- ── AJOUT 1 : un compte bloque ne recoit pas d'offre ──────────────────
    AND COALESCE(d.is_blocked, FALSE) = FALSE
    -- ── AJOUT 2 : position fraiche. 15 min = trois battements de coeur
    --    manques (l'app en envoie un toutes les 4 min). Sans cela, un
    --    livreur dont l'application a ete tuee reste eligible indefiniment.
    AND d.last_location_update IS NOT NULL
    AND d.last_location_update > now() - interval '15 minutes'
    AND d.current_lat   IS NOT NULL
    AND d.current_lng   IS NOT NULL
    AND public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT (d.id = ANY(COALESCE(v_passed, '{}'::UUID[])))
    AND NOT EXISTS (
      SELECT 1
      FROM   public.orders active
      WHERE  active.driver_id = d.id
        AND  active.status IN ('confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay')
    )
    AND NOT EXISTS (
      SELECT 1
      FROM   public.orders offered
      WHERE  offered.assigned_driver_id = d.id
        AND  offered.driver_id          IS NULL
        AND  offered.assignment_expires_at > now()
    )
  ORDER BY public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) ASC
  LIMIT 1;

  RETURN v_driver_id;
END;
$$;


-- ── 4. La tache : repasser hors ligne, SAUF en pleine livraison ────────────
-- Le point 3 protege deja le dispatch. Cette tache sert a ce que la carte,
-- les compteurs et l'application disent la meme chose que lui.
--
-- LA GARDE EST ESSENTIELLE. Si l'application d'un livreur est tuee par MIUI
-- au milieu d'une course, sa position cesse d'arriver : sans la garde, la
-- tache le passerait hors ligne, il disparaitrait de la carte admin en pleine
-- livraison, et au redemarrage l'application relirait is_online = false
-- (driver_online_provider le lit au demarrage) -- le livreur se retrouverait
-- hors ligne sans l'avoir demande, avec une commande sur les bras.
--
-- Tant qu'une commande est en cours, il reste donc en ligne. Cela ne lui
-- amene aucune offre parasite : next_eligible_driver ecarte deja les livreurs
-- ayant une livraison active. La meme liste de statuts est utilisee des deux
-- cotes, pour qu'ils ne puissent pas diverger.
SELECT cron.schedule(
  'offline_stale_drivers',
  '* * * * *',
  $job$
    UPDATE public.drivers d
    SET    is_online = false
    WHERE  d.is_online = true
      AND  (d.last_location_update IS NULL
            OR d.last_location_update < now() - interval '15 minutes')
      AND  NOT EXISTS (
             SELECT 1
             FROM   public.orders o
             WHERE  o.driver_id = d.id
               AND  o.status IN ('confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay')
           );
  $job$
);


-- ── 5. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
  FROM public.drivers d JOIN public.wallets w ON w.user_id = d.user_id
  WHERE d.is_blocked = true AND w.balance > 0 AND w.status = 'active';
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % blocage(s) incoherent(s) subsistent', n;
  END IF;

  SELECT count(*) INTO n FROM cron.job WHERE jobname = 'offline_stale_drivers';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la tache offline_stale_drivers n''est pas planifiee';
  END IF;

  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'update_wallet_balance'
     AND p.prosrc ~ 'GET DIAGNOSTICS';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : update_wallet_balance n''a pas ete remplacee';
  END IF;

  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'next_eligible_driver'
     AND p.prosrc ~ 'last_location_update' AND p.prosrc ~ 'is_blocked';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : next_eligible_driver n''a pas les deux conditions';
  END IF;
END
$$;

COMMIT;


-- ── B. Verification ────────────────────────────────────────────────────────
-- 1. Apres une minute, plus aucun livreur en ligne avec une position de plus
--    de 15 min -- sauf s'il a une commande en cours :
-- SELECT u.email, d.is_online,
--        ROUND(EXTRACT(EPOCH FROM (now()-d.last_location_update))/60) AS position_min,
--        EXISTS (SELECT 1 FROM public.orders o WHERE o.driver_id = d.id
--                AND o.status IN ('confirmed','preparing','ready','pickedUp','onTheWay')) AS en_course
-- FROM public.drivers d JOIN auth.users u ON u.id = d.user_id
-- WHERE d.is_online = true ORDER BY 3 DESC;
--
-- 2. La tache tourne sans erreur :
-- SELECT status, count(*) FROM cron.job_run_details
-- WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='offline_stale_drivers')
--   AND start_time > now() - interval '5 minutes' GROUP BY status;
--
-- 3. Le blocage fantome ne revient plus : livrez une commande et verifiez que
--    drivers.is_blocked reste false pour un livreur au solde positif.
