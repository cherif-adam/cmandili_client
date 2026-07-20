-- ============================================================================
-- CMANDILI — Bulk-apply customization templates (Phase 2)
--
-- Applies TEMPLATE A (Sauce au choix / Garniture au choix / Suppléments) to
-- every makloub, cornet, malfouf, baguette farcie and tabouna item across
-- every real restaurant, and TEMPLATE A + TEMPLATE B variants (Normal /
-- Mozzarella +1.20 / Cheddar +2.30, computed from each item's own price) to
-- every mlawi and calzone item.
--
-- Rules enforced:
--   1. Restaurants literally named "food", "plan", "restaurant" (test/seed
--      fixtures with identical malfouf data) are excluded entirely.
--   2. Items priced at 0 are excluded and reported for manual review — never
--      modified.
--   3. Any item that already has an option group linked OR a variant row
--      (Titanic food's "Makloub Cordon Bleu (N)" and "Mlawi Thon Fromage"
--      from the Phase 1 test seed) is skipped entirely — idempotent, never
--      duplicated/overwritten.
--   4. Any item name matching more than one family pattern is treated as
--      ambiguous and reported for manual review — never modified.
--
-- Groups are restaurant-scoped and reused by name: if a restaurant already
-- has "Sauce au choix" etc. (Titanic food does, from the Phase 1 seed), this
-- script links to the existing group instead of creating a duplicate.
--
-- Idempotent — safe to re-run. Anything already processed (or pre-existing)
-- is skipped on subsequent runs, so re-running after new menu items are
-- added will only touch the new items.
--
-- NOT executed by the assistant — paste into the SQL editor / run via
-- `supabase db query --linked -f this_file.sql` yourself after review.
--
-- 2026-07-20: Sauce au choix / Garniture au choix min_selections changed
-- 1 -> 0 (optional, like Suppléments always was) so this stays the single
-- source of truth alongside apply_customization_template_to_item() —
-- matters if this is ever re-run for a fresh batch of items. Existing
-- groups already in the DB are a separate one-off update, not this script;
-- see supabase/scripts/20260720_optional_sauce_garniture.sql.
-- ============================================================================

DO $$
DECLARE
  v_row                  RECORD;
  v_restaurant            RECORD;
  v_sauce_id              UUID;
  v_garniture_id          UUID;
  v_supp_id               UUID;
  v_groups_created        INT;
  v_items_linked          INT;
  v_variants_added        INT;
  v_skipped_existing      INT;
  v_total_ambiguous       INT := 0;
  v_total_zero_price      INT := 0;
  v_total_excluded_test   INT := 0;
  v_delta_mozzarella CONSTANT DOUBLE PRECISION := 1.20;
  v_delta_cheddar    CONSTANT DOUBLE PRECISION := 2.30;
BEGIN
  DROP TABLE IF EXISTS _bulk_customization_candidates;
  CREATE TEMP TABLE _bulk_customization_candidates AS
  WITH norm AS (
    SELECT
      fi.id AS food_item_id,
      fi.restaurant_id,
      r.name AS restaurant_name,
      fi.name AS item_name,
      fi.price,
      lower(translate(fi.name,
        'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ',
        'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'
      )) AS n_item
    FROM public.food_items fi
    JOIN public.restaurants r ON r.id = fi.restaurant_id
  )
  SELECT *,
    (n_item ~ 'maklou')::int
      + (n_item ~ 'cornet')::int
      + (n_item ~ 'malfou')::int
      + (n_item ~ 'farcie|baguette')::int
      + (n_item ~ 'tabouna|tabuna')::int
      + (n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou')::int
      + (n_item ~ 'calzone')::int AS n_family_matches,
    CASE
      WHEN n_item ~ 'maklou'                     THEN 'makloub'
      WHEN n_item ~ 'cornet'                      THEN 'cornet'
      WHEN n_item ~ 'malfou'                       THEN 'malfouf'
      WHEN n_item ~ 'farcie|baguette'               THEN 'baguette_farcie'
      WHEN n_item ~ 'tabouna|tabuna'                 THEN 'tabouna'
      WHEN n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou'      THEN 'mlawi'
      WHEN n_item ~ 'calzone'                          THEN 'calzone'
    END AS family,
    lower(restaurant_name) = ANY (ARRAY['food', 'plan', 'restaurant']) AS is_test_restaurant
  FROM norm
  WHERE n_item ~ 'maklou|cornet|malfou|farcie|baguette|tabouna|tabuna|m[ae]?l[ae]?w|mlaou|melaou|calzone';

  -- ── Report exclusions up front ──────────────────────────────────────────
  FOR v_row IN
    SELECT restaurant_name, count(*) AS n
    FROM _bulk_customization_candidates
    WHERE is_test_restaurant
    GROUP BY restaurant_name
  LOOP
    RAISE NOTICE 'EXCLUDED test/seed restaurant "%": % item(s) never touched', v_row.restaurant_name, v_row.n;
    v_total_excluded_test := v_total_excluded_test + v_row.n;
  END LOOP;

  FOR v_row IN
    SELECT * FROM _bulk_customization_candidates
    WHERE NOT is_test_restaurant AND n_family_matches > 1
  LOOP
    RAISE NOTICE 'AMBIGUOUS (needs manual review, not modified): restaurant="%" item="%" (matches % family patterns)',
      v_row.restaurant_name, v_row.item_name, v_row.n_family_matches;
    v_total_ambiguous := v_total_ambiguous + 1;
  END LOOP;

  FOR v_row IN
    SELECT * FROM _bulk_customization_candidates
    WHERE NOT is_test_restaurant AND n_family_matches = 1 AND price = 0
  LOOP
    RAISE NOTICE 'NEEDS MANUAL REVIEW (zero price, not modified): restaurant="%" item="%" family=%',
      v_row.restaurant_name, v_row.item_name, v_row.family;
    v_total_zero_price := v_total_zero_price + 1;
  END LOOP;

  RAISE NOTICE '── Exclusion summary: % test-restaurant item(s), % ambiguous, % zero-priced ──',
    v_total_excluded_test, v_total_ambiguous, v_total_zero_price;

  -- ── Main pass: one restaurant at a time ─────────────────────────────────
  FOR v_restaurant IN
    SELECT DISTINCT restaurant_id, restaurant_name
    FROM _bulk_customization_candidates
    WHERE NOT is_test_restaurant AND n_family_matches = 1 AND price > 0
    ORDER BY restaurant_name
  LOOP
    v_groups_created := 0;
    v_items_linked := 0;
    v_variants_added := 0;
    v_skipped_existing := 0;

    -- Reuse-by-name: Titanic food already has all three from the Phase 1 seed.
    SELECT id INTO v_sauce_id FROM public.food_item_option_groups
      WHERE restaurant_id = v_restaurant.restaurant_id AND name = 'Sauce au choix';
    IF v_sauce_id IS NULL THEN
      INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
        VALUES (v_restaurant.restaurant_id, 'Sauce au choix', 0, 4, 0)
        RETURNING id INTO v_sauce_id;
      INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
        (v_sauce_id, 'Harissa', 0, 0),
        (v_sauce_id, 'Mayonnaise', 0, 1),
        (v_sauce_id, 'Sauce Algérienne', 0, 2),
        (v_sauce_id, 'Salade Mechouia', 0, 3);
      v_groups_created := v_groups_created + 1;
    END IF;

    SELECT id INTO v_garniture_id FROM public.food_item_option_groups
      WHERE restaurant_id = v_restaurant.restaurant_id AND name = 'Garniture au choix';
    IF v_garniture_id IS NULL THEN
      INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
        VALUES (v_restaurant.restaurant_id, 'Garniture au choix', 0, 3, 1)
        RETURNING id INTO v_garniture_id;
      INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
        (v_garniture_id, 'Laitue', 0, 0),
        (v_garniture_id, 'Tomate', 0, 1),
        (v_garniture_id, 'Oignon', 0, 2);
      v_groups_created := v_groups_created + 1;
    END IF;

    SELECT id INTO v_supp_id FROM public.food_item_option_groups
      WHERE restaurant_id = v_restaurant.restaurant_id AND name = 'Suppléments';
    IF v_supp_id IS NULL THEN
      INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
        VALUES (v_restaurant.restaurant_id, 'Suppléments', 0, 4, 2)
        RETURNING id INTO v_supp_id;
      INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
        (v_supp_id, 'Gruyère', 6.0, 0),
        (v_supp_id, 'Fromage Arbi', 4.8, 1),
        (v_supp_id, 'Cheddar', 3.6, 2),
        (v_supp_id, 'Frisco', 6.0, 3);
      v_groups_created := v_groups_created + 1;
    END IF;

    FOR v_row IN
      SELECT * FROM _bulk_customization_candidates
      WHERE restaurant_id = v_restaurant.restaurant_id
        AND NOT is_test_restaurant AND n_family_matches = 1 AND price > 0
      ORDER BY item_name
    LOOP
      -- Idempotency / Rule 3: skip anything already customized (by anyone).
      IF EXISTS (SELECT 1 FROM public.food_item_option_group_links WHERE food_item_id = v_row.food_item_id)
         OR EXISTS (SELECT 1 FROM public.food_item_variants WHERE food_item_id = v_row.food_item_id) THEN
        v_skipped_existing := v_skipped_existing + 1;
        CONTINUE;
      END IF;

      INSERT INTO public.food_item_option_group_links (food_item_id, group_id, sort_order) VALUES
        (v_row.food_item_id, v_sauce_id, 0),
        (v_row.food_item_id, v_garniture_id, 1),
        (v_row.food_item_id, v_supp_id, 2)
      ON CONFLICT DO NOTHING;
      v_items_linked := v_items_linked + 1;

      -- Template B families additionally get "Type au choix" variants,
      -- computed from this item's own base price.
      IF v_row.family IN ('mlawi', 'calzone') THEN
        INSERT INTO public.food_item_variants (food_item_id, name, price, sort_order) VALUES
          (v_row.food_item_id, 'Normal', v_row.price, 0),
          (v_row.food_item_id, 'Mozzarella', round((v_row.price + v_delta_mozzarella)::numeric, 2)::double precision, 1),
          (v_row.food_item_id, 'Cheddar', round((v_row.price + v_delta_cheddar)::numeric, 2)::double precision, 2);
        v_variants_added := v_variants_added + 1;
      END IF;
    END LOOP;

    RAISE NOTICE 'Restaurant "%": created % new group(s), linked % item(s) to groups (% of those also got variants), skipped % already-customized item(s)',
      v_restaurant.restaurant_name, v_groups_created, v_items_linked, v_variants_added, v_skipped_existing;
  END LOOP;

  DROP TABLE IF EXISTS _bulk_customization_candidates;
END $$;
