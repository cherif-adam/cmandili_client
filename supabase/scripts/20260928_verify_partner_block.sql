-- ============================================================================
-- CMANDILI -- Verifier que orders_partner_update respecte is_blocked
--
-- Lecture seule en pratique : la policy est remplacee ICI, les deux cas sont
-- joues, puis le RAISE EXCEPTION final annule tout -- y compris le
-- remplacement de la policy (le DDL est transactionnel dans Postgres).
--
-- A lancer AVANT la migration pour constater le trou, et APRES pour constater
-- qu'il est bouche. Avant : les deux lignes renvoient 1. Apres : actif 1,
-- bloque 0.
--
-- On ecrit self_delivery (colonne autorisee au partenaire par
-- guard_orders_column_scope) plutot que status, pour mesurer la portee RLS
-- sans declencher les gardes de statut terminal.
-- ============================================================================
DO $$
DECLARE
  n    integer;
  out  text := E'\n';
  c    record;
BEGIN
  -- La policy telle que la migration la pose.
  DROP POLICY IF EXISTS "orders_partner_update" ON public.orders;
  CREATE POLICY "orders_partner_update"
    ON public.orders FOR UPDATE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.partners p
        WHERE p.user_id = auth.uid()
          AND coalesce(p.is_blocked, false) = false
          AND p.entity_id::text <> ''
          AND lower(p.entity_id::text) IN (orders.restaurant_id::text, orders.supermarket_id::text)
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.partners p
        WHERE p.user_id = auth.uid()
          AND coalesce(p.is_blocked, false) = false
          AND p.entity_id::text <> ''
          AND lower(p.entity_id::text) IN (orders.restaurant_id::text, orders.supermarket_id::text)
      )
    );

  -- Un partenaire de chaque etat, avec une de SES commandes.
  FOR c IN
    SELECT u.email,
           p.business_name,
           p.user_id,
           coalesce(p.is_blocked, false) AS bloque,
           (SELECT o.id FROM public.orders o
             WHERE o.restaurant_id = p.entity_id OR o.supermarket_id = p.entity_id
             ORDER BY o.created_at DESC LIMIT 1) AS oid
    FROM public.partners p
    JOIN auth.users u ON u.id = p.user_id
    WHERE EXISTS (SELECT 1 FROM public.orders o
                   WHERE o.restaurant_id = p.entity_id OR o.supermarket_id = p.entity_id)
    ORDER BY coalesce(p.is_blocked, false), u.email
  LOOP
    IF c.oid IS NULL THEN CONTINUE; END IF;

    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', c.user_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('role', 'authenticated', true);
    BEGIN
      WITH t AS (
        UPDATE public.orders SET self_delivery = NOT coalesce(self_delivery, false)
         WHERE id = c.oid RETURNING 1
      ) SELECT count(*) INTO n FROM t;
      out := out || format(E'  %-7s %-22s %s ligne(s)\n',
                           CASE WHEN c.bloque THEN 'BLOQUE' ELSE 'ACTIF' END,
                           c.business_name, n);
    EXCEPTION WHEN OTHERS THEN
      out := out || format(E'  %-7s %-22s exception : %s\n',
                           CASE WHEN c.bloque THEN 'BLOQUE' ELSE 'ACTIF' END,
                           c.business_name, SQLERRM);
    END;
    PERFORM set_config('role', 'postgres', true);
  END LOOP;

  RAISE EXCEPTION E'TEST orders_partner_update (tout annule) :%  attendu : ACTIF 1 ligne, BLOQUE 0 ligne', out;
END
$$;
