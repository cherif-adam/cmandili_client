-- ============================================================================
-- AMANA -- Les livreurs peuvent aussi supprimer leur compte depuis l'appli
--
-- NON EXECUTE. A lancer dans le SQL Editor APRES 20261017120000_delete_my_account.sql.
--
-- Meme fonction delete_my_account() que pour les clients, avec deux refus de
-- plus quand l'appelant est un livreur :
--   * 'active_delivery'  : une course qui lui est attribuee n'est ni livree ni
--                          annulee -- le client attend sa commande ;
--   * 'negative_balance' : son solde prepaye est negatif, il doit encore de
--                          l'argent -- a regler avec le support d'abord.
-- Un solde POSITIF n'empeche rien : l'appli previent qu'il est perdu.
--
-- Ce qui part et ce qui reste : voir 20261017120000. drivers, wallets,
-- settlements, notifications, device_tokens suivent auth.users en CASCADE ;
-- les commandes gardent leur driver_id (pas de cle etrangere).
-- ============================================================================

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

  -- Client : une commande en route a encore besoin de son client.
  IF EXISTS (
    SELECT 1 FROM public.orders
    WHERE user_id = uid
      AND status NOT IN ('delivered', 'cancelled')
  ) THEN
    RAISE EXCEPTION 'active_order';
  END IF;

  -- Livreur : une course attribuee et pas terminee.
  IF EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.drivers d ON d.id = o.driver_id OR d.id = o.assigned_driver_id
    WHERE d.user_id = uid
      AND o.status NOT IN ('delivered', 'cancelled')
  ) THEN
    RAISE EXCEPTION 'active_delivery';
  END IF;

  -- Livreur : un solde negatif est une dette envers Amana.
  IF EXISTS (
    SELECT 1 FROM public.wallets
    WHERE user_id = uid AND balance < 0
  ) THEN
    RAISE EXCEPTION 'negative_balance';
  END IF;

  -- Les notes vocales sont des enregistrements de la personne : le lien
  -- disparait des commandes gardees (l'appli client supprime les fichiers).
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
