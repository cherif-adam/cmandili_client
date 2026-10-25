-- ============================================================================
-- AMANA -- Un client peut supprimer son compte depuis l'application
--
-- NON EXECUTE. A relire, puis a lancer dans le SQL Editor du dashboard.
--
-- Google Play exige qu'un compte cree dans l'appli puisse etre supprime
-- depuis l'appli. L'appli ne peut pas supprimer un utilisateur auth elle-meme :
-- elle appelle public.delete_my_account(), qui supprime la ligne auth.users de
-- l'appelant (et seulement la sienne).
--
-- ── CE QUI PART AVEC LE COMPTE ─────────────────────────────────────────────
-- Tout ce qui pointe vers auth.users en ON DELETE CASCADE : profil, adresses,
-- destinataires enregistres, messages de l'assistant, notifications, avis,
-- jetons de notification, cartes enregistrees (payment_methods), etc.
-- Plus les liens vers les notes vocales des commandes passees (ci-dessous).
--
-- ── CE QUI RESTE, SANS LIEN AVEC LA PERSONNE ───────────────────────────────
-- Les commandes et les paiements : c'est l'historique des commerces et des
-- livreurs, et la comptabilite. orders.user_id etait en ON DELETE CASCADE
-- (supprimer un client aurait efface ses commandes chez tout le monde) : il
-- passe en ON DELETE SET NULL. Les apps livreur, partenaire et admin lisent
-- deja user_id avec une valeur par defaut, une commande sans client ne les
-- casse pas.
--
-- Toute contrainte NO ACTION / RESTRICT vers auth.users dans public
-- (public.payments.user_id, loyalty_driver_payouts.customer_id, ...) ferait
-- echouer la suppression : elle passe aussi en SET NULL, la ligne est gardee.
-- La liste exacte de ce qui change s'affiche en NOTICE a l'execution.
--
-- ── REFUS ──────────────────────────────────────────────────────────────────
-- Pas de suppression pendant une commande en cours : le commerce et le
-- livreur ont encore besoin de l'adresse et du telephone. L'appli affiche
-- alors un message (erreur 'active_order').
-- ============================================================================

BEGIN;

-- ── 1. Les commandes (et tout ce qui bloquerait) survivent au compte ────────
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.conname, t.relname, a.attname, c.confdeltype
    FROM pg_constraint c
    JOIN pg_class t      ON t.oid = c.conrelid
    JOIN pg_namespace n  ON n.oid = t.relnamespace
    JOIN pg_attribute a  ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND n.nspname = 'public'
      AND array_length(c.conkey, 1) = 1
      AND (c.confdeltype IN ('a', 'r')                                  -- NO ACTION / RESTRICT
           OR (t.relname = 'orders' AND a.attname = 'user_id' AND c.confdeltype = 'c'))
  LOOP
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I DROP NOT NULL', r.relname, r.attname);
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', r.relname, r.conname);
    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES auth.users(id) ON DELETE SET NULL',
      r.relname, r.conname, r.attname);
    RAISE NOTICE 'public.%.% : % -> SET NULL', r.relname, r.attname,
      CASE r.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' ELSE 'CASCADE' END;
  END LOOP;
END
$$;


-- ── 2. La fonction appelee par l'appli ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Une commande en route a encore besoin de son client.
  IF EXISTS (
    SELECT 1 FROM public.orders
    WHERE user_id = uid
      AND status NOT IN ('delivered', 'cancelled')
  ) THEN
    RAISE EXCEPTION 'active_order';
  END IF;

  -- Les notes vocales sont des enregistrements de la personne : le lien
  -- disparait des commandes gardees (l'appli supprime les fichiers).
  UPDATE public.order_items oi
     SET voice_note_url = NULL
    FROM public.orders o
   WHERE oi.order_id = o.id
     AND o.user_id = uid
     AND oi.voice_note_url IS NOT NULL;

  -- Le reste suit par les ON DELETE CASCADE / SET NULL.
  DELETE FROM auth.users WHERE id = uid;
END
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

COMMIT;


-- ── 3. Verification ────────────────────────────────────────────────────────
-- Attendu : aucune ligne (plus rien en NO ACTION / RESTRICT vers auth.users,
-- et orders.user_id en SET NULL).
SELECT t.relname AS table_name, a.attname AS column_name, c.confdeltype
FROM pg_constraint c
JOIN pg_class t     ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
WHERE c.contype = 'f'
  AND c.confrelid = 'auth.users'::regclass
  AND n.nspname = 'public'
  AND (c.confdeltype IN ('a', 'r')
       OR (t.relname = 'orders' AND a.attname = 'user_id' AND c.confdeltype <> 'n'));
