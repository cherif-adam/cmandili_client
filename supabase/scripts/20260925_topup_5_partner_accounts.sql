-- ============================================================================
-- CMANDILI -- Charger 50 TND sur les 5 comptes partenaires de test
--
-- NON EXECUTE. A lancer vous-meme apres relecture.
--
-- POURQUOI CE CHEMIN : c'est exactement ce que fait le bouton "Recharger" de
-- l'admin (app/api/wallet/topup/route.ts) -- une ligne `settlements` positive
-- de type 'manual_topup'. Les triggers font le reste :
--   update_wallet_balance()  cree la ligne wallets si elle n'existe pas et y
--                            applique le montant (INSERT ... ON CONFLICT)
--   enforce_prepaid_block()  compare au plancher global_settings
--                            .prepaid_min_balance (= 0 aujourd'hui) et laisse
--                            le compte actif tant que le solde le depasse
--
-- La seule difference avec un clic dans l'admin est la ligne audit_logs, que
-- la route ecrit avec l'id de l'admin connecte. Elle est ajoutee en option a
-- la fin, a decommenter si vous voulez la trace complete.
--
-- 50.000 TND = ce que portent les comptes restaurants qui fonctionnent
-- (piccolomondo, mecanopizza, planb, soltan, food1, restauu2, titanic).
--
-- Idempotence : ce script N'EST PAS idempotent -- le relancer recharge une
-- seconde fois. Le SELECT de controle en haut dit ou vous en etes.
-- ============================================================================

-- ── Avant : etat des 5 comptes ─────────────────────────────────────────────
SELECT u.email,
       p.partner_type,
       COALESCE(w.balance::text, 'aucun wallet') AS solde_avant,
       COALESCE(w.status, '-')                   AS statut_wallet,
       p.is_blocked                              AS partenaire_bloque
FROM public.partners p
JOIN auth.users u       ON u.id = p.user_id
LEFT JOIN public.wallets w ON w.user_id = p.user_id
WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                  'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com')
ORDER BY u.email;


BEGIN;

-- ── La recharge ────────────────────────────────────────────────────────────
-- entity_type = 'restaurant' : c'est la valeur que la route admin utilise
-- pour TOUT partenaire (settlements_entity_type_check n'accepte que
-- restaurant / supermarket / driver, il n'y a pas de valeur par categorie).
INSERT INTO public.settlements
  (user_id, entity_type, amount, type, description, status)
SELECT p.user_id,
       'restaurant',
       50.000,
       'manual_topup',
       'Recharge solde',
       'paid'
FROM public.partners p
JOIN auth.users u ON u.id = p.user_id
WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                  'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com');

-- ── Garde-fou : les 5 doivent finir a 50 TND et non bloques ────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
  FROM public.wallets w
  JOIN auth.users u ON u.id = w.user_id
  WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                    'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com')
    AND w.balance = 50.000
    AND w.status  = 'active';
  IF n <> 5 THEN
    RAISE EXCEPTION 'Abandon : % compte(s) a 50.000 TND et actifs, 5 attendus', n;
  END IF;
END
$$;

COMMIT;


-- ── Apres : verification ───────────────────────────────────────────────────
SELECT u.email, w.balance, w.status, w.blocked_reason, p.is_blocked
FROM public.wallets w
JOIN auth.users u        ON u.id = w.user_id
JOIN public.partners p   ON p.user_id = w.user_id
WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                  'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com')
ORDER BY u.email;
-- Attendu : 5 lignes, balance 50.000, status 'active', blocked_reason NULL,
-- is_blocked false.


-- ── Optionnel : la trace d'audit que la route admin aurait ecrite ──────────
-- Remplacez <VOTRE_ADMIN_UUID> par votre id (SELECT id FROM auth.users
-- WHERE email = 'ademcherif209@gmail.com').
--
-- INSERT INTO public.audit_logs (admin_id, admin_email, action_type, target_type, target_id, details)
-- SELECT '<VOTRE_ADMIN_UUID>'::uuid, 'ademcherif209@gmail.com', 'wallet_topup',
--        'restaurant', p.id, jsonb_build_object('amount', 50.000)
-- FROM public.partners p
-- JOIN auth.users u ON u.id = p.user_id
-- WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
--                   'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com');
