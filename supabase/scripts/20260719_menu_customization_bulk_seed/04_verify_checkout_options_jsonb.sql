-- ============================================================================
-- CMANDILI — Verify order_items.options JSONB after a manual test checkout
--
-- Run this in the SQL editor right after placing a test order that includes
-- at least one customized item (e.g. a Piccolo Mondo Makloub with sauce +
-- garniture selected, or a Melwi with a variant chosen).
--
-- Expected shape of `options` for a customized line, written by
-- order_repository.dart's placeOrder():
--   {
--     "variant": {"id": "...", "name": "Cheddar", "price": 8.3},        -- only if a variant was picked
--     "optionGroups": [
--       {
--         "groupId": "...", "groupName": "Sauce au choix",
--         "selections": [{"optionId": "...", "name": "Harissa", "price": 0}]
--       },
--       ...
--     ]
--     -- plus any OrderCustomization (special-instructions) fields spread at
--     -- the top level if "Instructions spéciales" was filled in.
--   }
-- A line added with NO customization (an item with no groups/variants, or
-- one where nothing beyond quantity was set) will have options = '{}'.
-- ============================================================================

SELECT
  o.id AS order_id,
  o.created_at,
  o.order_type,
  o.status,
  fi.name AS item_name,
  oi.quantity,
  oi.price AS line_price,
  oi.options,
  jsonb_pretty(oi.options) AS options_pretty,
  oi.options ? 'optionGroups' AS has_option_groups,
  oi.options ? 'variant' AS has_variant,
  jsonb_array_length(COALESCE(oi.options -> 'optionGroups', '[]'::jsonb)) AS n_option_groups
FROM public.order_items oi
JOIN public.orders o ON o.id = oi.order_id
LEFT JOIN public.food_items fi ON fi.id = oi.food_item_id
ORDER BY o.created_at DESC
LIMIT 20;
