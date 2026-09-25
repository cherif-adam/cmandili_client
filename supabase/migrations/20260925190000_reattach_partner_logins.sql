-- ============================================================================
-- CMANDILI -- Reattach the two re-registered logins to their original shops
--
-- RUN THIS THIRD, after:
--   1. 20260925180000_restore_partner_test_shops.sql
--   2. 20260925170000_restore_item_columns_and_partner_writes.sql
--
-- WHY IT EXISTS: on 2026-09-25 at 16:30 and 16:32, two of the five partner
-- logins were re-registered through the partner app, each creating a fresh
-- empty shop. partners.user_id is UNIQUE, so the restore script could not put
-- their original rows back -- it skipped them on purpose rather than take a
-- login away from a shop that had just been created. This finishes the job,
-- with the decision made explicitly: keep the ORIGINAL shops and their
-- articles, drop the two empty ones created today.
--
-- VERIFIED BEFORE WRITING THIS (all zero):
--   vendor_items / orders.restaurant_id / orders.supermarket_id /
--   user_favorites / order_ratings / food_item_option_groups pointing at
--   either of the two shops being removed. Nothing is lost with them.
--
-- auth.users is NOT touched. Both logins keep their password and their id;
-- only the row saying which shop they own changes.
--
-- The whole thing is one transaction with preconditions checked up front and
-- the end state asserted before COMMIT, so it either lands completely or not
-- at all.
-- ============================================================================

BEGIN;

-- ── 0. Refuse to run if the ground has moved since this was written ────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.vendor_items
   WHERE vendor_id IN ('0ed7a9a2-c24f-4864-a9f6-0aab528dd476',
                       'c8201361-60c0-47c8-9927-f6d8c2aa0200');
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % article(s) sur les boutiques a supprimer -- elles ne sont plus vides', n;
  END IF;

  SELECT count(*) INTO n FROM public.orders
   WHERE restaurant_id  IN ('0ed7a9a2-c24f-4864-a9f6-0aab528dd476','c8201361-60c0-47c8-9927-f6d8c2aa0200')
      OR supermarket_id IN ('0ed7a9a2-c24f-4864-a9f6-0aab528dd476','c8201361-60c0-47c8-9927-f6d8c2aa0200');
  IF n <> 0 THEN
    RAISE EXCEPTION 'Abandon : % commande(s) referencent les boutiques a supprimer', n;
  END IF;

  SELECT count(*) INTO n FROM public.vendors
   WHERE id IN ('98c1acad-a36c-49fd-ac15-2a0d8568ff4f','8c476faf-e1f5-404b-af08-8b9d522dfa90');
  IF n <> 2 THEN
    RAISE EXCEPTION 'Abandon : les boutiques d''origine sont absentes -- lancez d''abord 20260925180000_restore_partner_test_shops.sql';
  END IF;
END
$$;

-- ── 1. The two partner rows created on 2026-09-25, by id ───────────────────
--   1f217244  fleursdekairouan    restaurant  16:30:13  (animalerie@gmail.com)
--   ffb67c6e  fleurs de Kairouan  flowers     16:32:04  (fleursdekairouan@gmail.com)
DELETE FROM public.partners
 WHERE id IN ('1f217244-390c-42c5-a41b-95ac858ee6d4',
              'ffb67c6e-a58b-410a-9615-5d74b1598694');

-- ── 2. The two empty shops created on 2026-09-25, by id ────────────────────
--   c8201361  fleursdekairouan    food     16:30:12
--   0ed7a9a2  fleurs de Kairouan  flowers  16:32:03
DELETE FROM public.vendors
 WHERE id IN ('0ed7a9a2-c24f-4864-a9f6-0aab528dd476',
              'c8201361-60c0-47c8-9927-f6d8c2aa0200');

-- ── 3. Put the two original partner rows back ──────────────────────────────
-- Same ids, same entity_id, same created_at as before the 2026-09-24 deletion.
--   18a41cbd  Fleurs de Kairouan   -> vendor 98c1acad (7 articles)
--   45ec51ea  Animalerie El Amine  -> vendor 8c476faf (8 articles)
INSERT INTO public.partners
SELECT * FROM jsonb_populate_recordset(NULL::public.partners, '[{"id":"18a41cbd-5bb0-4168-beb1-1fb875dc49a1","user_id":"7f7b1c3e-34ee-4ca2-8582-9dc67fbe1f26","partner_type":"flowers","entity_id":"98c1acad-a36c-49fd-ac15-2a0d8568ff4f","business_name":"Fleurs de Kairouan","address":"Fleurs de Kairouan","phone":"","bio":"","avatar_url":"","created_at":"2026-09-22T23:26:23.209662+00:00","commission_rate":null,"is_blocked":false},{"id":"45ec51ea-ed1c-4c47-9261-c3e44de5f4f8","user_id":"903186da-6771-45f4-a656-d3b9e96e6223","partner_type":"pets","entity_id":"8c476faf-e1f5-404b-af08-8b9d522dfa90","business_name":"Animalerie El Amine","address":"Animalerie El Amine","phone":"","bio":"","avatar_url":"","created_at":"2026-09-22T23:26:23.509189+00:00","commission_rate":null,"is_blocked":false}]'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ── 4. Assert the end state before committing ──────────────────────────────
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
    FROM public.partners p
    JOIN public.vendors v ON v.id = p.entity_id
   WHERE p.user_id IN ('7f7b1c3e-34ee-4ca2-8582-9dc67fbe1f26',
                       '903186da-6771-45f4-a656-d3b9e96e6223',
                       '51110762-8992-43f9-bfe0-407579d84274',
                       'aaa996d7-7e2b-44aa-b598-99372b54084a',
                       '33187181-c146-41bf-8dfb-83e68ddc1fb7');
  IF n <> 5 THEN
    RAISE EXCEPTION 'Abandon : % compte(s) partenaire relies a une boutique, 5 attendus', n;
  END IF;
END
$$;

COMMIT;

-- ── Verification ───────────────────────────────────────────────────────────
-- SELECT u.email, p.partner_type, v.name AS boutique, v.category,
--        (SELECT count(*) FROM public.vendor_items i WHERE i.vendor_id = v.id) AS articles
-- FROM public.partners p
-- JOIN public.vendors v ON v.id = p.entity_id
-- JOIN auth.users u ON u.id = p.user_id
-- WHERE u.email IN ('fleursdekairouan@gmail.com','animalerie@gmail.com','delice@gmail.com',
--                   'digital@gmail.com','cadeau@gmail.com')
-- ORDER BY u.email;
-- Attendu : 5 lignes -- Animalerie El Amine 8, Boutique Nour 5,
--           Delices de Kairouan 5, Digital House 6, Fleurs de Kairouan 7.
