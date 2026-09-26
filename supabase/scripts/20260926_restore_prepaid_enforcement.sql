-- ============================================================================
-- CMANDILI -- Remettre le solde prepaye en etat de marche
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- Trois choses, dans UNE transaction :
--   1. recharger Boutique Nour jusqu'a 50 TND (chemin du bouton admin)
--   2. lever le blocage MANUEL de texas et sanfour, sous conditions
--   3. reappliquer la policy orders_partner_update de 20260925200000,
--      celle qui verifie is_blocked
--
-- POURQUOI LE POINT 3 : la policy live a ete appliquee a la main, hors
-- migration, et a perdu la condition `p.is_blocked = false`. Mesure en
-- transaction annulee avant d'ecrire ce fichier :
--
--   Boutique Nour  (BLOQUE)    1 ligne(s)
--   Texas food     (BLOQUE)    1 ligne(s)
--   Digital House  (actif)     1 ligne(s)
--
-- Un partenaire bloque ecrivait exactement comme un actif : tout le
-- mecanisme de solde prepaye ne gouvernait plus rien.
--
-- ORDRE IMPORTANT : la recharge et les deblocages passent AVANT la policy.
-- Si la policy etait remise en premier, Boutique Nour resterait bloquee le
-- temps de la transaction -- sans consequence ici, mais l'ordre choisi fait
-- que l'etat final est coherent a chaque etape.
--
-- Idempotent : relancable sans effet de bord (la recharge ne se declenche
-- que si le solde est sous 50, les deblocages que si le compte est bloque).
-- ============================================================================


-- ── A. Etat avant ──────────────────────────────────────────────────────────
SELECT u.email,
       p.business_name,
       p.is_blocked            AS partenaire_bloque,
       w.balance               AS solde,
       w.status                AS wallet,
       COALESCE(w.blocked_reason, '-') AS raison
FROM public.partners p
JOIN auth.users u          ON u.id = p.user_id
LEFT JOIN public.wallets w ON w.user_id = p.user_id
WHERE u.email IN ('cadeau@gmail.com', 'texas@gmail.com', 'sanfour@gmail.com')
ORDER BY u.email;


BEGIN;

-- ── 1. Recharger Boutique Nour jusqu'a 50 TND ──────────────────────────────
-- Le montant est calcule a l'execution (50 - solde actuel), parce que le
-- solde bouge a chaque commande livree : il etait a -6.210 il y a vingt
-- minutes, -37.010 au moment d'ecrire ce fichier. Figer un montant le
-- rendrait faux avant meme d'etre lance.
--
-- entity_type = 'restaurant' : la valeur que la route admin utilise pour
-- TOUT partenaire (settlements_entity_type_check n'accepte que
-- restaurant / supermarket / driver).
--
-- Aucun UPDATE sur wallets ici : le trigger update_wallet_balance applique
-- le montant, et enforce_prepaid_block leve automatiquement le blocage
-- puisque blocked_reason vaut 'balance'.
INSERT INTO public.settlements
  (user_id, entity_type, amount, type, description, status)
SELECT p.user_id,
       'restaurant',
       ROUND(50.000 - w.balance, 3),
       'manual_topup',
       'Recharge solde',
       'paid'
FROM public.partners p
JOIN auth.users u       ON u.id = p.user_id
JOIN public.wallets w   ON w.user_id = p.user_id
WHERE u.email = 'cadeau@gmail.com'
  AND w.balance < 50.000;


-- ── 2. Lever le blocage manuel de texas et sanfour ─────────────────────────
-- Uniquement si le solde est positif ET le wallet 'active' : ces deux-la
-- sont bloques alors que leur wallet va bien (43.510 et 48.020, tous deux
-- 'active', blocked_reason NULL), donc le blocage vient d'une action admin
-- jamais levee -- l'auto-deblocage ne se declenche qu'a un changement de
-- solde, il ne les aurait jamais rattrapes.
--
-- La condition protege le cas inverse : si l'un d'eux passait a un solde
-- negatif d'ici l'execution, il ne serait PAS debloque.
UPDATE public.partners p
SET    is_blocked = false
FROM   auth.users u, public.wallets w
WHERE  u.id = p.user_id
  AND  w.user_id = p.user_id
  AND  u.email IN ('texas@gmail.com', 'sanfour@gmail.com')
  AND  p.is_blocked = true
  AND  w.balance > 0
  AND  w.status = 'active';


-- ── 3. Reappliquer la policy qui verifie is_blocked ────────────────────────
-- Texte repris de 20260925200000_partner_order_writes_all_categories.sql.
-- Toujours pas de liste de partner_type : la question est "ce partenaire
-- possede-t-il cette boutique", vraie pour n'importe quelle categorie. La
-- difference avec la version appliquee a la main est la ligne is_blocked.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies
             WHERE schemaname='public' AND tablename='orders'
               AND policyname='orders_partner_update') THEN
    EXECUTE 'DROP POLICY orders_partner_update ON public.orders';
  END IF;
END
$$;

CREATE POLICY orders_partner_update
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.user_id    = auth.uid()
        AND p.is_blocked = false
        AND p.entity_id::text ~ '^[0-9a-f-]{36}$'
        AND (p.entity_id::text::uuid = orders.restaurant_id
          OR p.entity_id::text::uuid = orders.supermarket_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.user_id    = auth.uid()
        AND p.is_blocked = false
        AND p.entity_id::text ~ '^[0-9a-f-]{36}$'
        AND (p.entity_id::text::uuid = orders.restaurant_id
          OR p.entity_id::text::uuid = orders.supermarket_id)
    )
  );


-- ── 4. Garde-fou avant COMMIT ──────────────────────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
  FROM public.wallets w
  JOIN auth.users u ON u.id = w.user_id
  WHERE u.email = 'cadeau@gmail.com' AND w.balance = 50.000 AND w.status = 'active';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : Boutique Nour n''est pas a 50.000 TND / active';
  END IF;

  SELECT count(*) INTO n
  FROM public.partners p
  JOIN auth.users u ON u.id = p.user_id
  WHERE u.email IN ('texas@gmail.com', 'sanfour@gmail.com') AND p.is_blocked = false;
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : % compte(s) debloque(s) sur texas/sanfour, 2 attendus', n;
  END IF;

  SELECT count(*) INTO n
  FROM pg_policies
  WHERE schemaname='public' AND tablename='orders'
    AND policyname='orders_partner_update'
    AND COALESCE(qual,'') LIKE '%is_blocked%';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Abandon : la policy ne verifie pas is_blocked';
  END IF;
END
$$;

COMMIT;


-- ── B. Etat apres ──────────────────────────────────────────────────────────
SELECT u.email,
       p.business_name,
       p.is_blocked            AS partenaire_bloque,
       w.balance               AS solde,
       w.status                AS wallet,
       COALESCE(w.blocked_reason, '-') AS raison
FROM public.partners p
JOIN auth.users u          ON u.id = p.user_id
LEFT JOIN public.wallets w ON w.user_id = p.user_id
WHERE u.email IN ('cadeau@gmail.com', 'texas@gmail.com', 'sanfour@gmail.com')
ORDER BY u.email;
-- Attendu : Boutique Nour 50.000 active non bloquee,
--           texas 43.510 active non bloque, sanfour 48.020 active non bloque.
