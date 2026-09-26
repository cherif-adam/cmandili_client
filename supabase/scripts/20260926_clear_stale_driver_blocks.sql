-- ============================================================================
-- CMANDILI -- Lever les blocages livreurs devenus obsoletes
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- LE SYMPTOME : un livreur passe en ligne, sa position part bien, mais aucun
-- point vert n'apparait sur /dashboard/carte.
--
-- LA CAUSE : le point EST dessine -- en ROUGE, pas en vert. colorFor() dans
-- components/LiveMap.tsx renvoie rouge des que is_blocked vaut true, avant
-- meme de regarder si le livreur a une course. La carte n'ecarte pas les
-- livreurs bloques, elle les colore.
--
-- Releve au moment du diagnostic pour adem@gmail.com (profil "Mohamed") :
--   is_online             true
--   current_lat / lng     35.6758473 / 10.1090554
--   last_location_update  2026-09-26 17:06:08 UTC   (3,6 min, pas dans le futur)
--   is_blocked            TRUE            <-- la seule anomalie
--   wallet                54.402 TND, status 'active', blocked_reason NULL
--
-- Le portefeuille est sain : ce blocage ne correspond a rien. Il n'y a aucune
-- trace dans audit_logs, donc il ne vient pas du bouton "Bloquer" de l'admin.
-- Et enforce_prepaid_block ne peut pas le rattraper : sa branche de
-- deblocage ne s'execute que si le wallet est 'blocked', or il est 'active'.
-- Le drapeau reste donc vrai indefiniment.
--
-- 6 livreurs sur 11 sont dans ce cas. Les 5 autres sont bloques a juste titre
-- (solde <= 0, wallet 'blocked', raison 'balance') et la condition ci-dessous
-- les laisse tranquilles.
--
--   adam@gmail.com     98.850  active   -> a debloquer
--   adem@gmail.com     54.402  active   -> a debloquer  (le compte teste)
--   adem1@gmail.com   298.850  active   -> a debloquer
--   amin2212@gmail.co  48.850  active   -> a debloquer
--   drive@gmail.com   249.391  active   -> a debloquer
--   rafik2@gmail.co    98.850  active   -> a debloquer
--   akil1@gmail.com    -1.150  blocked  -> reste bloque
--   aymen@gmail.com    -7.932  blocked  -> reste bloque
--   firas1@gmail.com    0.000  blocked  -> reste bloque
--   firas123@gmail.com  0.000  blocked  -> reste bloque
--   moetez2@gmail.com   0.000  blocked  -> reste bloque
--
-- Idempotent : relancable, il ne touche que les lignes encore bloquees.
-- ============================================================================


-- ── A. Avant ───────────────────────────────────────────────────────────────
SELECT u.email, COALESCE(p.full_name, '?') AS nom, d.is_blocked,
       COALESCE(w.balance::text, 'aucun wallet') AS solde,
       COALESCE(w.status, '-') AS wallet,
       COALESCE(w.blocked_reason, '-') AS raison
FROM public.drivers d
JOIN auth.users u          ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
LEFT JOIN public.wallets w  ON w.user_id = d.user_id
WHERE d.is_blocked = true
ORDER BY u.email;


BEGIN;

-- ── 1. Lever uniquement les blocages sans justification ────────────────────
-- La condition est la meme que pour les partenaires la semaine derniere :
-- solde strictement positif ET wallet 'active'. Un livreur reellement a sec
-- ne remplit ni l'une ni l'autre, il reste donc bloque.
UPDATE public.drivers d
SET    is_blocked = false
FROM   public.wallets w
WHERE  w.user_id = d.user_id
  AND  d.is_blocked = true
  AND  w.balance > 0
  AND  w.status = 'active';


-- ── 2. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n_obsoletes integer; n_legitimes integer;
BEGIN
  -- Plus aucun blocage sur un portefeuille sain.
  SELECT count(*) INTO n_obsoletes
  FROM public.drivers d JOIN public.wallets w ON w.user_id = d.user_id
  WHERE d.is_blocked = true AND w.balance > 0 AND w.status = 'active';
  IF n_obsoletes <> 0 THEN
    RAISE EXCEPTION 'Abandon : % blocage(s) obsolete(s) subsistent', n_obsoletes;
  END IF;

  -- Et les blocages legitimes sont intacts.
  SELECT count(*) INTO n_legitimes
  FROM public.drivers d JOIN public.wallets w ON w.user_id = d.user_id
  WHERE d.is_blocked = true;
  IF n_legitimes <> 5 THEN
    RAISE EXCEPTION 'Abandon : % livreur(s) encore bloque(s), 5 attendus', n_legitimes;
  END IF;
END
$$;

COMMIT;


-- ── B. Apres ───────────────────────────────────────────────────────────────
SELECT u.email, COALESCE(p.full_name, '?') AS nom, d.is_blocked,
       w.balance AS solde, w.status AS wallet
FROM public.drivers d
JOIN auth.users u          ON u.id = d.user_id
LEFT JOIN public.profiles p ON p.id = d.user_id
LEFT JOIN public.wallets w  ON w.user_id = d.user_id
ORDER BY d.is_blocked DESC, u.email;
-- Attendu : 5 livreurs encore bloques (tous a solde <= 0), adem@gmail.com
-- parmi les debloques.
