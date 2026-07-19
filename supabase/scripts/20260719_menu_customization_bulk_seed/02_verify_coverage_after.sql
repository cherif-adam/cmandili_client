-- ============================================================================
-- CMANDILI — Coverage verification AFTER running 01_bulk_apply_customization_templates.sql
--
-- Restaurant × family: how many eligible items now have groups / variants,
-- plus the same zero-priced / ambiguous counts as a cross-check against the
-- RAISE NOTICE output from the apply run. Read-only.
-- ============================================================================

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
),
classified AS (
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
)
SELECT
  restaurant_name,
  family,
  count(*) FILTER (WHERE n_family_matches = 1)                       AS eligible_items,
  count(*) FILTER (WHERE n_family_matches > 1)                       AS ambiguous_excluded,
  count(*) FILTER (WHERE n_family_matches = 1 AND price = 0)         AS zero_priced_excluded,
  count(*) FILTER (
    WHERE n_family_matches = 1 AND price > 0
      AND EXISTS (SELECT 1 FROM public.food_item_option_group_links l WHERE l.food_item_id = classified.food_item_id)
  ) AS items_with_groups,
  count(*) FILTER (
    WHERE n_family_matches = 1 AND price > 0
      AND EXISTS (SELECT 1 FROM public.food_item_variants v WHERE v.food_item_id = classified.food_item_id)
  ) AS items_with_variants
FROM classified
GROUP BY restaurant_name, family
ORDER BY restaurant_name, family;
