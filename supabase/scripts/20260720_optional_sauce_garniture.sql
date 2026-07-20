-- ============================================================================
-- CMANDILI — Make "Sauce au choix" / "Garniture au choix" optional
--
-- Customers must be able to add an item with zero selections — no forced
-- choices. Sets min_selections = 0 on every EXISTING "Sauce au choix" and
-- "Garniture au choix" group, across all restaurants, matching how
-- "Suppléments" already works. max_selections is untouched.
--
-- is_required is a generated column (min_selections > 0), so it flips to
-- false automatically — nothing else to update for these rows. No "Aucun"
-- placeholder option is added or needed: the client already renders a
-- min=0 group correctly (Facultatif chip, "Sélectionnez jusqu'à N", Add to
-- cart enabled at 0 selections) — verified against the Suppléments group,
-- which has used min_selections = 0 since it was first seeded.
--
-- Idempotent — safe to re-run. The UPDATE only touches rows that still have
-- min_selections <> 0, so a second run affects 0 rows.
--
-- NOT executed by the assistant — paste into the SQL editor / run via
-- `supabase db query --linked -f this_file.sql` yourself after reviewing
-- the pre-count below.
-- ============================================================================

-- ── 1. Pre-check: exactly what this will touch ─────────────────────────────
SELECT name, min_selections, max_selections, count(*) AS n_groups,
       count(DISTINCT restaurant_id) AS n_restaurants
FROM public.food_item_option_groups
WHERE name IN ('Sauce au choix', 'Garniture au choix')
GROUP BY name, min_selections, max_selections
ORDER BY name;
-- Expected today (2026-07-20): Sauce au choix min=1/max=4 x4 groups / 4
-- restaurants, Garniture au choix min=1/max=3 x4 groups / 4 restaurants —
-- 8 rows total will be updated below. If this doesn't match, stop and check
-- before running the UPDATE (a group with a different min/max than expected
-- may need a closer look rather than a blind mass update).

-- ── 2. The update ────────────────────────────────────────────────────────
UPDATE public.food_item_option_groups
SET min_selections = 0
WHERE name IN ('Sauce au choix', 'Garniture au choix')
  AND min_selections <> 0;

-- ── 3. Post-check: confirm the new state ────────────────────────────────
SELECT name, min_selections, max_selections, is_required, count(*) AS n_groups
FROM public.food_item_option_groups
WHERE name IN ('Sauce au choix', 'Garniture au choix')
GROUP BY name, min_selections, max_selections, is_required
ORDER BY name;
-- Expected after: both names show min_selections=0, is_required=false,
-- max_selections unchanged (4 / 3), single row each (all groups converged).
