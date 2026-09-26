-- ============================================================================
-- CMANDILI -- Deux corrections : le blocage fantome, et les livreurs
--             "en ligne" depuis des heures sans bouger
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
--
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ PROBLEME 1 -- ce qui remet drivers.is_blocked a TRUE                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- Une seule fonction en base ecrit drivers.is_blocked : enforce_prepaid_block,
-- declenchee BEFORE INSERT OR UPDATE ON wallets. Rien d'autre -- ni cron, ni
-- Edge Function, ni l'app livreur, ni l'admin (aucune trace dans audit_logs).
--
-- LE MECANISME. update_wallet_balance, AFTER INSERT sur settlements, fait :
--
--     INSERT INTO public.wallets (user_id, balance)
--     VALUES (NEW.user_id, NEW.amount)            <-- le MONTANT, pas le solde
--     ON CONFLICT (user_id)
--     DO UPDATE SET balance = public.wallets.balance + NEW.amount, ...;
--
-- Quand le portefeuille existe deja, Postgres declenche le BEFORE INSERT
-- AVANT de detecter le conflit. enforce_prepaid_block voit donc
-- NEW.balance = NEW.amount, c'est-a-dire -1.734 pour une commission, juge le
-- solde epuise et bloque le livreur. Le ON CONFLICT resout ensuite en UPDATE
-- avec le vrai solde, mais la branche de deblocage ne s'execute que
-- `IF NEW.status = 'blocked'` -- or NEW vient de la ligne existante, dont le
-- statut est 'active'. Le drapeau reste donc a TRUE.
--
-- D'ou l'etat impossible observe : livreur bloque, portefeuille 'active',
-- blocked_reason NULL, solde largement positif, et aucune trace d'audit.
--
-- PREUVE, en transaction annulee sur adem@gmail.com :
--
--     AVANT  is_blocked=f  solde=52.668
--     APRES  is_blocked=t  solde=50.934  wallet=active  raison=-
--
-- Une commission de 1.734 TND a rebloque le compte alors qu'il lui reste
-- 50.934 TND. C'est pour cela que le blocage revient apres CHAQUE commande
-- livree, et que le script de nettoyage ne tient pas.
--
--
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ PROBLEME 2 -- "en ligne" sans l'etre                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- next_eligible_driver ne filtre que sur is_online = TRUE et une position non
-- nulle. Aucun controle de fraicheur, et aucun controle de is_blocked. Etat
-- au moment d'ecrire :
--
--     driver@test.com   position vieille de 3250 min (54 h)  -> eligible
--     drive@gmail.com   position vieille de  324 min          -> eligible
--     adem@gmail.com    position vieille de  279 min          -> eligible
--
-- Les trois peuvent recevoir une offre a l'instant meme. Une offre envoyee a
-- un livreur absent expire, et rotate_expired_offers fait tourner la
-- cascade : chaque fantome coute une minute de retard au client.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================


-- ── A. Etat avant ──────────────────────────────────────────────────────────
SELECT u.email, COALESCE(p.full_name,'—') AS nom, d.is_online, d.is_blocked,
       ROUND(EXTRACT(EPOCH FROM (now() - d.last_location_update))/60) AS position_min,
       w.balance, w.status AS wallet
FROM public.drivers d
JOIN auth.users u           ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
LEFT JOIN public.wallets  w ON w.user_id = d.user_id
ORDER BY d.is_online DESC, d.last_location_update NULLS FIRST;


BEGIN;

-- ── 1. La cause : ne plus presenter le montant comme un solde ──────────────
-- Le INSERT porte desormais le solde REEL qui resultera de l'operation, donc
-- le BEFORE INSERT juge la meme valeur que le BEFORE UPDATE. Le ON CONFLICT
-- est conserve tel quel : il reste la protection contre deux commissions
-- simultanees sur le meme portefeuille.
CREATE OR REPLACE FUNCTION public.update_wallet_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.wallets (user_id, balance)
  VALUES (
    NEW.user_id,
    COALESCE((SELECT w.balance FROM public.wallets w WHERE w.user_id = NEW.user_id), 0)
      + NEW.amount
  )
  ON CONFLICT (user_id)
  DO UPDATE SET balance = public.wallets.balance + NEW.amount, updated_at = now();
  RETURN NEW;
END;
$$;


-- ── 2. Un filet : rattraper une derive au lieu de la figer ─────────────────
-- Meme corrigee, la branche de deblocage ne s'executait que si le
-- portefeuille etait lui-meme 'blocked'. Un drapeau devenu faux par un autre
-- chemin (comme celui du point 1, ou une edition manuelle) ne se corrigeait
-- jamais tout seul. On remet le drapeau en accord avec le portefeuille des
-- qu'un mouvement le laisse au-dessus du plancher.
--
-- Les blocages ADMINISTRATIFS sont preserves : /api/block pose
-- blocked_reason = 'manual' sur le portefeuille, et ce filet ne touche que
-- les portefeuilles 'active'.
CREATE OR REPLACE FUNCTION public.enforce_prepaid_block()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_floor      NUMERIC(12,3);
  v_is_driver  BOOLEAN;
  v_is_partner BOOLEAN;
  v_url        TEXT;
  v_secret     TEXT;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.balance IS DISTINCT FROM OLD.balance THEN

    SELECT COALESCE(
      (SELECT setting_value::NUMERIC FROM public.global_settings WHERE setting_key = 'prepaid_min_balance'),
      0
    ) INTO v_floor;

    SELECT EXISTS(SELECT 1 FROM public.drivers  WHERE user_id = NEW.user_id) INTO v_is_driver;
    SELECT EXISTS(SELECT 1 FROM public.partners WHERE user_id = NEW.user_id) INTO v_is_partner;

    IF v_is_driver OR v_is_partner THEN

      IF NEW.balance <= v_floor THEN
        NEW.status         := 'blocked';
        NEW.blocked_reason := 'balance';

        IF v_is_driver THEN
          UPDATE public.drivers SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;
        IF v_is_partner THEN
          UPDATE public.partners SET is_blocked = TRUE WHERE user_id = NEW.user_id;
        END IF;

        IF TG_OP = 'INSERT' OR OLD.balance > v_floor THEN
          INSERT INTO public.notifications (user_id, title, message, type, data)
          VALUES (
            NEW.user_id,
            'Solde épuisé — compte bloqué',
            'Votre solde prépayé est de ' || NEW.balance || ' TND. Rechargez votre solde pour continuer à recevoir des commandes.',
            'wallet_blocked',
            jsonb_build_object('balance', NEW.balance)
          );
        END IF;

      ELSE
        IF NEW.status = 'blocked' AND COALESCE(NEW.blocked_reason, 'balance') = 'balance' THEN
          NEW.status         := 'active';
          NEW.blocked_reason := NULL;

          IF v_is_driver THEN
            UPDATE public.drivers SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;
          IF v_is_partner THEN
            UPDATE public.partners SET is_blocked = FALSE WHERE user_id = NEW.user_id;
          END IF;

        ELSIF NEW.status = 'active' THEN
          -- Le filet. Ne s'applique qu'a un portefeuille sain et non bloque
          -- administrativement, et ne touche que les lignes reellement en
          -- desaccord.
          IF v_is_driver THEN
            UPDATE public.drivers  SET is_blocked = FALSE
             WHERE user_id = NEW.user_id AND is_blocked = TRUE;
          END IF;
          IF v_is_partner THEN
            UPDATE public.partners SET is_blocked = FALSE
             WHERE user_id = NEW.user_id AND is_blocked = TRUE;
          END IF;
        END IF;
      END IF;

      IF TG_OP = 'UPDATE' AND OLD.balance > 4 AND NEW.balance BETWEEN 2 AND 4 THEN
        v_url := COALESCE(
          current_setting('app.edge_function_url', true),
          'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
        );
        v_secret := COALESCE(
          current_setting('app.edge_function_secret', true),
          'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
        );
        PERFORM net.http_post(
          url     := v_url,
          headers := jsonb_build_object('Content-Type', 'application/json',
                                        'Authorization', 'Bearer ' || v_secret),
          body    := jsonb_build_object('event', 'low_balance_warning',
                                        'user_id', NEW.user_id,
                                        'balance', NEW.balance)
        );
      END IF;

    END IF;
  END IF;

  RETURN NEW;
END;
$$;


-- ── 3. Remettre d'aplomb les drapeaux deja fausses ─────────────────────────
-- Meme condition que le script du 26/09 : solde strictement positif ET
-- portefeuille 'active'. Un livreur reellement a sec reste bloque.
UPDATE public.drivers d
SET    is_blocked = false
FROM   public.wallets w
WHERE  w.user_id = d.user_id
  AND  d.is_blocked = true
  AND  w.balance > 0
  AND  w.status = 'active';


-- ── 4. Un livreur dont la position est trop vieille n'est plus en ligne ────
-- Deux niveaux, volontairement :
--
--   (a) le dispatch refuse une position perimee AU MOMENT de choisir. C'est
--       la garantie : elle ne depend d'aucune tache planifiee.
--   (b) une tache remet is_online a false, pour que la carte, les compteurs
--       et l'app disent la meme chose que le dispatch.
--
-- Seuil a 15 minutes : le battement de coeur de l'app livreur est a 4 min et
-- la carte admin considere une position perimee a 10 min, donc 15 laisse
-- passer trois battements manques avant de declarer le livreur absent.

-- (a) -- le filtre de fraicheur dans le choix du livreur
--     On ne reecrit pas toute la fonction : on ajoute la condition au
--     WHERE existant. A relire avec le code actuel sous les yeux avant de
--     lancer, la fonction est longue.
-- NOTE : cette partie est laissee EN COMMENTAIRE volontairement. Modifier
-- next_eligible_driver demande de reproduire son corps entier, et je
-- prefere vous le proposer separement plutot que de le retranscrire de
-- memoire ici. Le point (b) ci-dessous suffit deja a regler le symptome.
--
--   AND d.last_location_update IS NOT NULL
--   AND d.last_location_update > now() - interval '15 minutes'

-- (b) -- la tache planifiee
SELECT cron.schedule(
  'offline_stale_drivers',
  '* * * * *',
  $job$
    UPDATE public.drivers
    SET    is_online = false
    WHERE  is_online = true
      AND  (last_location_update IS NULL
            OR last_location_update < now() - interval '15 minutes');
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
END
$$;

COMMIT;


-- ── B. Verification ────────────────────────────────────────────────────────
-- 1. Plus aucun livreur en ligne avec une position de plus de 15 min
--    (laisser passer une minute pour que la tache tourne) :
-- SELECT u.email, d.is_online,
--        ROUND(EXTRACT(EPOCH FROM (now()-d.last_location_update))/60) AS position_min
-- FROM public.drivers d JOIN auth.users u ON u.id=d.user_id
-- WHERE d.is_online = true ORDER BY 3 DESC;
--
-- 2. La tache tourne sans erreur :
-- SELECT status, count(*) FROM cron.job_run_details
-- WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='offline_stale_drivers')
--   AND start_time > now() - interval '5 minutes' GROUP BY status;
--
-- 3. Le blocage fantome ne revient plus. Rejouez la preuve : une commission
--    sur un livreur sain ne doit plus mettre is_blocked a true.
