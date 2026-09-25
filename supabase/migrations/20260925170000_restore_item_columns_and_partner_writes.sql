-- ============================================================================
-- CMANDILI -- Restore partner item writes and Happy Hour after the vendors split
--
-- NOT EXECUTED BY THE ASSISTANT. Review, take the backup named at the bottom,
-- then run it yourself (SQL editor, or `supabase db push`).
--
-- ── THE EVIDENCE (all gathered read-only against the live project) ──────────
--
-- 1. Uploads work, the rows never move. Every file uploaded to the `items`
--    bucket from 2026-09-21 20:47 onward is an orphan -- 10 consecutive
--    uploads, not one referenced by any vendor_items row. Everything up to
--    2026-09-18 23:49 IS referenced. The break is in the write, not the
--    upload, and it started with the vendors/vendor_items consolidation.
--
-- 2. `food_items` and `grocery_items` are no longer tables. They are views
--    over vendor_items (JOIN vendors, WHERE v.category = 'food'/'grocery')
--    with INSTEAD OF INSERT/UPDATE/DELETE triggers. vendor_items never
--    received the food-specific columns, so the views cannot expose them:
--
--      food_items    : id, restaurant_id, name, description, image_url,
--                      price, category, is_available, created_at
--      vendor_items  : ... discount_price, discount_end_time, sort_order ...
--      food_items_legacy (still has them): preparation_time, is_vegetarian,
--                      is_spicy, discount_price, discount_end_time,
--                      discount_quantity, is_happy_hour, happy_hour_price,
--                      happy_hour_start, happy_hour_end
--
--    So every one of these fails today with PGRST204 / 42703 (verified by
--    sending each app's exact payload at a uuid that matches no row, so
--    nothing was written):
--
--      MenuRepository.updateFoodItem  -> 400 "Could not find the
--                                        'happy_hour_end' column of
--                                        'food_items'"
--      MenuRepository.setHappyHour    -> 400 "... 'discount_end_time' column
--                                        of 'food_items'"        (restaurant)
--      MenuRepository.setHappyHour    -> 400 "... 'discount_quantity' column
--                                        of 'grocery_items'"     (supermarket)
--      client happy_hour_provider GET -> 400 "column
--                                        food_items.discount_price does not
--                                        exist"
--
-- 3. The generic-vendor path (the 5 new accounts) fails SILENTLY instead.
--    Its payload is valid, so PostgREST accepts it -- but RLS matches no row:
--
--      vendor_items has RLS enabled, and its only write policy is
--      `vendor_items_owner_write` FOR ALL
--        USING / WITH CHECK (EXISTS (SELECT 1 FROM vendors v
--                            WHERE v.id = vendor_items.vendor_id
--                              AND v.owner_id = auth.uid()))
--
--      and `SELECT count(*), count(owner_id) FROM vendors` returns 14, 0 --
--      owner_id is NULL on EVERY vendor. The predicate can never be true for
--      anybody. An UPDATE therefore touches 0 rows, PostgREST answers 200/204
--      with no error, supabase-dart does not throw, and the app reports
--      success while nothing changed. Ownership actually lives in
--      partners.entity_id (13 rows), which the policy never consults.
--
-- 4. The Happy Hour auto-end has been dead since the same change.
--    cron job 1 `disable_happy_hour` (every minute) runs
--      UPDATE food_items SET is_happy_hour = false
--      WHERE is_happy_hour = true AND current_time > happy_hour_end;
--    cron.job_run_details: 120 runs in the last 2 hours, 120 failed,
--      ERROR: column "is_happy_hour" does not exist
--    It was also comparing a UTC `current_time` against a Tunis-local
--    happy_hour_end, so it would have closed offers an hour early even when
--    the column existed.
--
-- Idempotent -- safe to re-run.
-- ============================================================================


-- ── 1. Give vendor_items the columns the food path lost ────────────────────
-- Types mirror food_items_legacy exactly so the backfill cannot round or
-- truncate. discount_price / discount_end_time already exist.

-- is_happy_hour is added WITHOUT a default on purpose. With
-- `DEFAULT false`, every existing row would be stamped false immediately and
-- the COALESCE(vi.is_happy_hour, l.is_happy_hour) backfill in step 2 could
-- never fall through to the legacy value -- every happy hour configured
-- before the split would be silently lost. The default is set in step 2b,
-- after the copy.

ALTER TABLE public.vendor_items
  ADD COLUMN IF NOT EXISTS preparation_time  integer,
  ADD COLUMN IF NOT EXISTS is_vegetarian     boolean,
  ADD COLUMN IF NOT EXISTS is_spicy          boolean,
  ADD COLUMN IF NOT EXISTS discount_quantity integer,
  ADD COLUMN IF NOT EXISTS is_happy_hour     boolean,
  ADD COLUMN IF NOT EXISTS happy_hour_price  numeric,
  ADD COLUMN IF NOT EXISTS happy_hour_start  time without time zone,
  ADD COLUMN IF NOT EXISTS happy_hour_end    time without time zone;


-- ── 2. Backfill from the legacy table ──────────────────────────────────────
-- Every legacy id already exists in vendor_items with the same id (verified
-- when the legacy tables were frozen), so this is a straight column copy for
-- the rows that have one. Only writes where vendor_items is still NULL, so a
-- value edited since the split is never clobbered by a stale legacy one.

UPDATE public.vendor_items vi
SET preparation_time  = COALESCE(vi.preparation_time,  l.preparation_time),
    is_vegetarian     = COALESCE(vi.is_vegetarian,     l.is_vegetarian),
    is_spicy          = COALESCE(vi.is_spicy,          l.is_spicy),
    discount_quantity = COALESCE(vi.discount_quantity, l.discount_quantity),
    is_happy_hour     = COALESCE(vi.is_happy_hour,     l.is_happy_hour),
    happy_hour_price  = COALESCE(vi.happy_hour_price,  l.happy_hour_price),
    happy_hour_start  = COALESCE(vi.happy_hour_start,  l.happy_hour_start),
    happy_hour_end    = COALESCE(vi.happy_hour_end,    l.happy_hour_end),
    discount_price    = COALESCE(vi.discount_price,    l.discount_price),
    discount_end_time = COALESCE(vi.discount_end_time, l.discount_end_time)
FROM public.food_items_legacy l
WHERE l.id = vi.id;


-- ── 2b. Only now give is_happy_hour its default ────────────────────────────
-- Order matters: the column had to stay nullable through the backfill above
-- so COALESCE could tell "never set" from "set to false". Rows with no legacy
-- counterpart are settled to false here.

UPDATE public.vendor_items SET is_happy_hour = false WHERE is_happy_hour IS NULL;

ALTER TABLE public.vendor_items ALTER COLUMN is_happy_hour SET DEFAULT false;
ALTER TABLE public.vendor_items ALTER COLUMN is_happy_hour SET NOT NULL;


-- ── 3. Views expose them again ─────────────────────────────────────────────
-- CREATE OR REPLACE VIEW can only append columns, never reorder or rename
-- existing ones -- every new column goes after created_at, which is why the
-- order below looks odd. Appending also keeps the INSTEAD OF triggers
-- attached, so they do not have to be dropped and recreated.

CREATE OR REPLACE VIEW public.food_items AS
  SELECT vi.id,
         vi.vendor_id AS restaurant_id,
         vi.name,
         vi.description,
         vi.image_url,
         vi.price,
         vi.category,
         vi.is_available,
         vi.created_at,
         vi.preparation_time,
         vi.is_vegetarian,
         vi.is_spicy,
         vi.discount_price,
         vi.discount_end_time,
         vi.discount_quantity,
         vi.is_happy_hour,
         vi.happy_hour_price,
         vi.happy_hour_start,
         vi.happy_hour_end
  FROM public.vendor_items vi
  JOIN public.vendors v ON v.id = vi.vendor_id
  WHERE v.category = 'food'::text;

CREATE OR REPLACE VIEW public.grocery_items AS
  SELECT vi.id,
         vi.vendor_id AS supermarket_id,
         vi.name,
         vi.description,
         vi.image_url,
         vi.price,
         vi.category,
         vi.unit,
         vi.is_organic,
         vi.is_available,
         vi.discount_price,
         vi.discount_end_time,
         vi.created_at,
         vi.discount_quantity
  FROM public.vendor_items vi
  JOIN public.vendors v ON v.id = vi.vendor_id
  WHERE v.category = 'grocery'::text;


-- ── 4. Triggers propagate the new columns ──────────────────────────────────
-- The UPDATE branches previously wrote six columns and dropped everything
-- else on the floor, which is why an edit that "succeeded" could still lose
-- the preparation time or the happy hour.

CREATE OR REPLACE FUNCTION public.food_items_write()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF tg_op = 'INSERT' THEN
    INSERT INTO public.vendor_items
      (id, vendor_id, name, description, image_url, price, category,
       is_available, preparation_time, is_vegetarian, is_spicy,
       discount_price, discount_end_time, discount_quantity,
       is_happy_hour, happy_hour_price, happy_hour_start, happy_hour_end)
    VALUES (
      COALESCE(new.id, gen_random_uuid()), new.restaurant_id, new.name,
      new.description, new.image_url, COALESCE(new.price, 0), new.category,
      COALESCE(new.is_available, true), new.preparation_time,
      new.is_vegetarian, new.is_spicy, new.discount_price,
      new.discount_end_time, new.discount_quantity,
      COALESCE(new.is_happy_hour, false), new.happy_hour_price,
      new.happy_hour_start, new.happy_hour_end
    )
    RETURNING id INTO new.id;
    RETURN new;

  ELSIF tg_op = 'UPDATE' THEN
    UPDATE public.vendor_items SET
      name              = new.name,
      description       = new.description,
      image_url         = new.image_url,
      price             = new.price,
      category          = new.category,
      is_available      = new.is_available,
      preparation_time  = new.preparation_time,
      is_vegetarian     = new.is_vegetarian,
      is_spicy          = new.is_spicy,
      discount_price    = new.discount_price,
      discount_end_time = new.discount_end_time,
      discount_quantity = new.discount_quantity,
      is_happy_hour     = new.is_happy_hour,
      happy_hour_price  = new.happy_hour_price,
      happy_hour_start  = new.happy_hour_start,
      happy_hour_end    = new.happy_hour_end
    WHERE id = old.id;
    RETURN new;

  ELSE
    DELETE FROM public.vendor_items WHERE id = old.id;
    RETURN old;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.grocery_items_write()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF tg_op = 'INSERT' THEN
    INSERT INTO public.vendor_items
      (id, vendor_id, name, description, image_url, price, category, unit,
       is_organic, is_available, discount_price, discount_end_time,
       discount_quantity)
    VALUES (
      COALESCE(new.id, gen_random_uuid()), new.supermarket_id, new.name,
      new.description, new.image_url, COALESCE(new.price, 0), new.category,
      new.unit, COALESCE(new.is_organic, false),
      COALESCE(new.is_available, true), new.discount_price,
      new.discount_end_time, new.discount_quantity
    )
    RETURNING id INTO new.id;
    RETURN new;

  ELSIF tg_op = 'UPDATE' THEN
    UPDATE public.vendor_items SET
      name              = new.name,
      description       = new.description,
      image_url         = new.image_url,
      price             = new.price,
      category          = new.category,
      unit              = new.unit,
      is_organic        = new.is_organic,
      is_available      = new.is_available,
      discount_price    = new.discount_price,
      discount_end_time = new.discount_end_time,
      discount_quantity = new.discount_quantity
    WHERE id = old.id;
    RETURN new;

  ELSE
    DELETE FROM public.vendor_items WHERE id = old.id;
    RETURN old;
  END IF;
END;
$$;


-- ── 5. Let the actual owner write ──────────────────────────────────────────
-- vendors.owner_id is NULL on every row and nothing in any app writes it;
-- partner signup writes partners.entity_id instead. Rather than backfill a
-- column no code maintains, the check consults both -- owner_id for whatever
-- may set it later, partners for what the apps actually use.
--
-- SECURITY DEFINER because `partners` has its own RLS: a plain subquery
-- inside the policy is evaluated as the caller and would be filtered by it.
-- Both branches are bound to auth.uid(), so there is no identity-free path
-- that would let one partner claim another's items.

CREATE OR REPLACE FUNCTION public.owns_vendor(p_vendor_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
           SELECT 1 FROM public.vendors v
           WHERE v.id = p_vendor_id AND v.owner_id = auth.uid()
         )
      OR EXISTS (
           SELECT 1 FROM public.partners p
           WHERE p.entity_id = p_vendor_id AND p.user_id = auth.uid()
         );
$$;

REVOKE EXECUTE ON FUNCTION public.owns_vendor(uuid) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.owns_vendor(uuid) TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies
             WHERE schemaname = 'public' AND tablename = 'vendor_items'
               AND policyname = 'vendor_items_owner_write') THEN
    EXECUTE 'DROP POLICY vendor_items_owner_write ON public.vendor_items';
  END IF;
END;
$$;

CREATE POLICY vendor_items_owner_write
  ON public.vendor_items
  FOR ALL
  TO authenticated
  USING (public.owns_vendor(vendor_id))
  WITH CHECK (public.owns_vendor(vendor_id));


-- ── 6. Repair the auto-end cron job ────────────────────────────────────────
-- Points at vendor_items (the view has no is_happy_hour to filter on before
-- step 3, and going straight at the table is one less layer either way), and
-- compares Tunis local time rather than UTC -- the old job would have ended
-- every happy hour an hour early.

SELECT cron.schedule(
  'disable_happy_hour',
  '* * * * *',
  $job$
    UPDATE public.vendor_items
    SET    is_happy_hour = false
    WHERE  is_happy_hour = true
      AND  happy_hour_end IS NOT NULL
      AND  (now() AT TIME ZONE 'Africa/Tunis')::time > happy_hour_end;
  $job$
);


-- ── 7. Verification (run after, expect the commented values) ───────────────
-- SELECT count(*) FILTER (WHERE column_name = 'happy_hour_end') AS hh_end,
--        count(*) FILTER (WHERE column_name = 'discount_price') AS disc
-- FROM information_schema.columns
-- WHERE table_schema='public' AND table_name='food_items';        -- 1, 1
--
-- SELECT count(*) FILTER (WHERE column_name='discount_quantity')
-- FROM information_schema.columns
-- WHERE table_schema='public' AND table_name='grocery_items';     -- 1
--
-- SELECT status, count(*) FROM cron.job_run_details
-- WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='disable_happy_hour')
--   AND start_time > now() - interval '5 minutes'
-- GROUP BY status;                                    -- succeeded, no failed
--
-- BACKUP BEFORE RUNNING:
--   supabase db dump --linked -f backups/pre-item-columns-YYYYMMDD.sql
--   (schema + data for public; keep it until a partner has edited an item
--    and the client has shown a promo price.)
