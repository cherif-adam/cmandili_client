-- ============================================================================
-- CMANDILI — Targeted ROLLBACK for 01_bulk_apply_customization_templates.sql
--
-- Deletes ONLY what the bulk apply script would have inserted, by re-deriving
-- the same restaurant/item classification the apply script uses. Explicitly
-- preserves:
--   - Titanic food's pre-existing "Makloub Cordon Bleu (N)" group links and
--     "Mlawi Thon Fromage" variants (the Phase 1 test seed) — excluded by
--     exact restaurant+item-name identity.
--   - Titanic food's three option groups themselves (Sauce au choix /
--     Garniture au choix / Suppléments) — they pre-date this bulk run and are
--     REUSED, not created, by the apply script, so rollback must not drop
--     them even though it does drop the same-named groups it created fresh
--     for every other restaurant.
--   - Any group/variant/link that isn't part of this exact template.
--
-- Mechanism (see chat for full rationale):
--   - food_item_option_groups / food_item_options: deleted by exact template
--     name, restricted to restaurant_id <> Titanic food's id. Safe because a
--     live audit (run immediately before writing this script) confirmed ZERO
--     option groups existed anywhere outside Titanic food prior to the bulk
--     run — so any such group found on another restaurant can only have come
--     from this bulk run. Options cascade-delete via their FK.
--   - food_item_option_group_links: no created_at column exists on this
--     join table, so it cannot be time-scoped. Instead, deletion is scoped to
--     links pointing at a template-named group AND whose food_item_id is in
--     the re-derived candidate set (same matching regex, non-test
--     restaurant, non-zero price, unambiguous family, minus the one known
--     pre-existing Titanic makloub item).
--   - food_item_variants: scoped to food_item_id in the re-derived candidate
--     set (mlawi/calzone families only, minus the one known pre-existing
--     Titanic mlawi item) AND variant name IN ('Normal','Mozzarella','Cheddar').
--
-- LIMITS — read before running:
--   1. The link-table deletion depends on re-matching TODAY's food_items
--      name/price data with the identical classification logic used at apply
--      time. If an item was renamed or re-priced (e.g. dropped to 0) between
--      the apply run and this rollback, it will silently fall out of the
--      candidate set and its bulk-created link rows will be left orphaned
--      (not deleted). Run rollback soon after apply, or verify against the
--      apply run's own RAISE NOTICE output first.
--   2. If a restaurant partner independently created their own group or
--      variant using the exact same names this template uses ("Sauce au
--      choix", "Normal"/"Mozzarella"/"Cheddar", etc.) AFTER the bulk apply
--      but BEFORE this rollback, it is indistinguishable from a bulk-created
--      row by name alone and would also be deleted. There is no batch/audit
--      id column on any of these tables to disambiguate — that would need a
--      schema change (e.g. a nullable `created_by_batch text` column), which
--      is out of scope here but worth considering if more bulk scripts like
--      this are planned.
--   3. This script assumes it runs to completion in one transaction (a
--      single DO $$ block). If you need a dry run first, use the preview
--      SELECT below — swap the DELETEs for it before running anything.
--
-- NOT executed by the assistant — review, then run yourself.
-- ============================================================================

DO $$
DECLARE
  v_groups_deleted   INT := 0;
  v_links_deleted    INT := 0;
  v_variants_deleted INT := 0;
  v_titanic_id       UUID;
BEGIN
  SELECT id INTO v_titanic_id FROM public.restaurants WHERE name = 'Titanic food';

  DROP TABLE IF EXISTS _bulk_rollback_candidates;
  CREATE TEMP TABLE _bulk_rollback_candidates AS
  WITH norm AS (
    SELECT
      fi.id AS food_item_id, fi.restaurant_id, r.name AS restaurant_name,
      fi.name AS item_name, fi.price,
      lower(translate(fi.name,
        'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ',
        'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'
      )) AS n_item
    FROM public.food_items fi
    JOIN public.restaurants r ON r.id = fi.restaurant_id
  )
  SELECT *,
    (n_item ~ 'maklou')::int + (n_item ~ 'cornet')::int + (n_item ~ 'malfou')::int
      + (n_item ~ 'farcie|baguette')::int + (n_item ~ 'tabouna|tabuna')::int
      + (n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou')::int + (n_item ~ 'calzone')::int AS n_family_matches,
    CASE
      WHEN n_item ~ 'maklou' THEN 'makloub'
      WHEN n_item ~ 'cornet' THEN 'cornet'
      WHEN n_item ~ 'malfou' THEN 'malfouf'
      WHEN n_item ~ 'farcie|baguette' THEN 'baguette_farcie'
      WHEN n_item ~ 'tabouna|tabuna' THEN 'tabouna'
      WHEN n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou' THEN 'mlawi'
      WHEN n_item ~ 'calzone' THEN 'calzone'
    END AS family
  FROM norm
  WHERE n_item ~ 'maklou|cornet|malfou|farcie|baguette|tabouna|tabuna|m[ae]?l[ae]?w|mlaou|melaou|calzone'
    AND lower(restaurant_name) <> ALL (ARRAY['food', 'plan', 'restaurant'])
    AND price > 0
    AND NOT (restaurant_name = 'Titanic food' AND item_name = 'Makloub Cordon Bleu (N)')
    AND NOT (restaurant_name = 'Titanic food' AND item_name = 'Mlawi Thon Fromage');

  -- Drop rows that matched more than one family pattern (never touched by apply).
  DELETE FROM _bulk_rollback_candidates WHERE n_family_matches <> 1;

  -- 1) Links from candidate items to the three template groups.
  WITH del AS (
    DELETE FROM public.food_item_option_group_links l
    USING public.food_item_option_groups g
    WHERE l.group_id = g.id
      AND g.name IN ('Sauce au choix', 'Garniture au choix', 'Suppléments')
      AND l.food_item_id IN (SELECT food_item_id FROM _bulk_rollback_candidates)
    RETURNING l.food_item_id
  )
  SELECT count(*) INTO v_links_deleted FROM del;

  -- 2) Variants for candidate mlawi/calzone items, exact template names only.
  WITH del AS (
    DELETE FROM public.food_item_variants v
    WHERE v.food_item_id IN (
      SELECT food_item_id FROM _bulk_rollback_candidates WHERE family IN ('mlawi', 'calzone')
    )
    AND v.name IN ('Normal', 'Mozzarella', 'Cheddar')
    RETURNING v.food_item_id
  )
  SELECT count(*) INTO v_variants_deleted FROM del;

  -- 3) The template groups themselves (cascades their options), everywhere
  --    EXCEPT Titanic food, whose three groups pre-date this bulk run.
  WITH del AS (
    DELETE FROM public.food_item_option_groups g
    WHERE g.name IN ('Sauce au choix', 'Garniture au choix', 'Suppléments')
      AND g.restaurant_id IS DISTINCT FROM v_titanic_id
    RETURNING g.id
  )
  SELECT count(*) INTO v_groups_deleted FROM del;

  RAISE NOTICE 'Rollback complete: % group(s) deleted (options cascaded), % link row(s) deleted, % variant row(s) deleted. Titanic food''s pre-existing seed (groups + "Mlawi Thon Fromage" variants) was left untouched.',
    v_groups_deleted, v_links_deleted, v_variants_deleted;

  DROP TABLE IF EXISTS _bulk_rollback_candidates;
END $$;

-- ----------------------------------------------------------------------------
-- Optional dry run — run this SELECT instead of the DO block above to see
-- exactly which food_items/groups/variants would be touched, before deleting
-- anything.
-- ----------------------------------------------------------------------------
-- WITH norm AS (
--   SELECT
--     fi.id AS food_item_id, fi.restaurant_id, r.name AS restaurant_name,
--     fi.name AS item_name, fi.price,
--     lower(translate(fi.name,
--       'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ',
--       'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'
--     )) AS n_item
--   FROM public.food_items fi JOIN public.restaurants r ON r.id = fi.restaurant_id
-- ),
-- classified AS (
--   SELECT *,
--     (n_item ~ 'maklou')::int + (n_item ~ 'cornet')::int + (n_item ~ 'malfou')::int
--       + (n_item ~ 'farcie|baguette')::int + (n_item ~ 'tabouna|tabuna')::int
--       + (n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou')::int + (n_item ~ 'calzone')::int AS n_family_matches,
--     CASE
--       WHEN n_item ~ 'maklou' THEN 'makloub'
--       WHEN n_item ~ 'cornet' THEN 'cornet'
--       WHEN n_item ~ 'malfou' THEN 'malfouf'
--       WHEN n_item ~ 'farcie|baguette' THEN 'baguette_farcie'
--       WHEN n_item ~ 'tabouna|tabuna' THEN 'tabouna'
--       WHEN n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou' THEN 'mlawi'
--       WHEN n_item ~ 'calzone' THEN 'calzone'
--     END AS family
--   FROM norm
--   WHERE n_item ~ 'maklou|cornet|malfou|farcie|baguette|tabouna|tabuna|m[ae]?l[ae]?w|mlaou|melaou|calzone'
-- )
-- SELECT restaurant_name, item_name, family, price
-- FROM classified
-- WHERE lower(restaurant_name) <> ALL (ARRAY['food', 'plan', 'restaurant'])
--   AND n_family_matches = 1
--   AND price > 0
--   AND NOT (restaurant_name = 'Titanic food' AND item_name = 'Makloub Cordon Bleu (N)')
--   AND NOT (restaurant_name = 'Titanic food' AND item_name = 'Mlawi Thon Fromage')
-- ORDER BY restaurant_name, family, item_name;
