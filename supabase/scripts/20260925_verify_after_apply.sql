-- ============================================================================
-- CMANDILI -- Verification pass, to run AFTER the three scripts have landed
--
--   1. 20260925180000_restore_partner_test_shops.sql
--   2. 20260925170000_restore_item_columns_and_partner_writes.sql
--   3. 20260925190000_reattach_partner_logins.sql
--
-- Read-only except for section D, which opens a transaction, attempts a real
-- UPDATE as each of the five partner logins, and ROLLS BACK. Nothing it
-- touches is committed -- the point is to find out whether the new RLS policy
-- would let the write through, which only a real attempt can answer.
-- ============================================================================


-- ── A. The columns are exposed again (expect hh_end 1, disc 1) ─────────────
SELECT count(*) FILTER (WHERE column_name = 'happy_hour_end')  AS hh_end,
       count(*) FILTER (WHERE column_name = 'discount_price')  AS disc,
       count(*) FILTER (WHERE column_name = 'discount_quantity') AS disc_qty
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'food_items';

-- expect disc_qty 1
SELECT count(*) FILTER (WHERE column_name = 'discount_quantity') AS disc_qty
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'grocery_items';


-- ── B. The happy-hour cron job stopped failing ─────────────────────────────
-- Expect only 'succeeded'. Run at least 2 minutes after applying.
SELECT status, count(*) AS runs, max(start_time) AS last_run
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'disable_happy_hour')
  AND start_time > now() - interval '5 minutes'
GROUP BY status;


-- ── C. The five shops are back, wired to the right login ───────────────────
-- Expect 5 rows: Animalerie El Amine 8, Boutique Nour 5,
-- Délices de Kairouan 5, Digital House 6, Fleurs de Kairouan 7.
SELECT u.email,
       p.partner_type,
       v.name     AS boutique,
       v.category,
       (SELECT count(*) FROM public.vendor_items i WHERE i.vendor_id = v.id) AS articles
FROM public.partners p
JOIN public.vendors v  ON v.id = p.entity_id
JOIN auth.users    u   ON u.id = p.user_id
WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                  'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com')
ORDER BY u.email;

-- And the two shops created on 2026-09-25 are gone (expect 0).
SELECT count(*) AS lignes_restantes
FROM public.vendors
WHERE id IN ('0ed7a9a2-c24f-4864-a9f6-0aab528dd476',
             'c8201361-60c0-47c8-9927-f6d8c2aa0200');


-- ── D. Can each login actually write its own items now? ────────────────────
-- Impersonates each partner the way PostgREST does -- role `authenticated`
-- plus a JWT claim carrying their user id -- then makes the smallest possible
-- real UPDATE (sets image_url to itself) and counts the rows RLS let through.
-- ROLLBACK at the end, so nothing survives this block.
--
-- Expect: rows_updated > 0 for all five. A 0 means the policy still does not
-- recognise that login as the owner.

BEGIN;

DO $$
DECLARE
  r          record;
  n          integer;
  results    text := '';
BEGIN
  FOR r IN
    SELECT u.email, p.user_id, p.entity_id, v.name
    FROM public.partners p
    JOIN public.vendors v ON v.id = p.entity_id
    JOIN auth.users    u  ON u.id = p.user_id
    WHERE u.email IN ('fleursdekairouan@gmail.com', 'animalerie@gmail.com',
                      'delice@gmail.com', 'digital@gmail.com', 'cadeau@gmail.com')
    ORDER BY u.email
  LOOP
    -- Become that partner for the next statement.
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims',
                       json_build_object('sub', r.user_id, 'role', 'authenticated')::text,
                       true);

    WITH touched AS (
      UPDATE public.vendor_items
      SET    image_url = image_url
      WHERE  vendor_id = r.entity_id
      RETURNING 1
    )
    SELECT count(*) INTO n FROM touched;

    -- Back to the privileged role to read the next row of the loop.
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claims', NULL, true);

    results := results || format(E'\n  %-30s %-22s rows_updated = %s',
                                 r.email, r.name, n);
  END LOOP;

  RAISE NOTICE 'RLS write test (rolled back):%', results;
END
$$;

ROLLBACK;
