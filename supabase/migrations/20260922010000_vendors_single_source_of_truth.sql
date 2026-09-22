-- ============================================================================
-- CMANDILI -- Make `vendors` the single source of truth for venue data
--
-- THE DECISION: vendors wins. restaurants_legacy / supermarkets_legacy become
-- derived mirrors, not independent copies.
--
-- Evidence this is the right way round, not a coin flip:
--   1. Every writer in the codebase already targets vendors. The partner app
--      writes it directly (edit_profile_screen.dart:94, home_screen.dart:125);
--      the admin app writes `restaurants` / `supermarkets`, which are simple
--      auto-updatable VIEWS over vendors (toggle-ghost, categories routes), so
--      those writes land in vendors too. NOTHING in any of the four apps
--      writes to a *_legacy table.
--   2. Every client-facing view already reads it: restaurants, supermarkets,
--      food_items and grocery_items are all `SELECT ... FROM vendors` /
--      `FROM vendor_items` filtered by category.
--   3. vendors is a strict superset: 29 venues vs 14 in legacy, 656 items vs
--      570. The newer categories (flowers, pets, gifts, bakery, electronics)
--      exist ONLY in vendors -- the legacy tables structurally cannot hold
--      them, which is why the multi-category work introduced vendors at all.
--   4. Every legacy id already exists in vendors/vendor_items with the same
--      id: 0 missing across all four legacy tables. They are duplicates, not
--      partitions.
--
-- So the legacy tables survive for exactly one reason: 14 FK constraints still
-- point at them (orders.restaurant_id, orders.supermarket_id,
-- order_items.food_item_id, order_items.grocery_item_id, order_ratings,
-- user_favorites, food_item_option_groups, food_item_variants,
-- restaurant_option_template_state, supermarket_products, ...). They are
-- write-orphaned referential anchors -- which is precisely WHY they drifted:
-- nothing has updated them in normal operation since the vendors split.
--
-- WHAT WENT WRONG (the bug this fixes): tonight's geocoding pass wrote the
-- corrected coordinates to restaurants_legacy / supermarkets_legacy -- the
-- copy almost nothing reads. The driver's tracking screen reads `vendors`
-- (order_tracking_screen.dart:93), so it still routed to the old shared
-- placeholder 35.6781,10.0994 for every restaurant, and to 0,0 for amoud and
-- Monoprix Kairouan 2. The client app, reading the `restaurants` view, saw the
-- same stale values.
--
-- THIS MIGRATION (phase 1 of 2):
--   a. Pushes the corrected coordinates into vendors, where they belong.
--   b. Installs a trigger so vendors -> legacy stays in sync automatically.
--      After this, legacy cannot drift again: it is derived, not authored.
--
-- PHASE 2 (deliberately NOT bundled here -- see the note at the bottom):
--   repoint the 14 FKs at vendors/vendor_items, drop the legacy tables, and
--   revert the `*_legacy` aliases added to the driver/partner queries today.
--   That needs an app rebuild + retest, so it wants its own window.
--
-- Idempotent -- safe to re-run.
-- ============================================================================


-- ── 1. Correct vendors with tonight's geocoded coordinates ──────────────────
-- Source: Google Places Text Search, 2026-09-21, confident single-result
-- matches only (see the geocoding report). These are the same values applied
-- to the legacy tables earlier; this puts them in the authoritative copy.
-- Written as an explicit VALUES list rather than "copy whatever legacy has" so
-- the provenance stays auditable and re-running can't silently propagate a bad
-- legacy value.

UPDATE public.vendors v
SET latitude = c.lat, longitude = c.lng
FROM (VALUES
  ('64ab3c24-ad1d-44ae-b586-5187941e5fc3'::uuid, 35.6713923, 10.0983037), -- Texas food
  ('f3b6d38f-02f4-4553-956c-5679a4911f65'::uuid, 35.6843623, 10.0972447), -- Piccolo Mondo
  ('99fcc696-d439-479e-8c1f-9627e8420b49'::uuid, 35.6728440, 10.1022918), -- Seven pizza Kairouan
  ('826852ac-cfff-4a45-9b68-aeae313a0da8'::uuid, 35.6708324, 10.1018774), -- mecano pizza Kairouan
  ('e61eccbe-8df5-4c8d-8941-f4de07a1de2f'::uuid, 35.6757812, 10.1087717), -- plan  (Plan B kairouan)
  ('5b262991-5c7f-45a9-b855-fad07b15f9fe'::uuid, 35.6716470, 10.1008215), -- amoud (Patisserie Amoud)
  ('16658e52-1c73-4731-8ce6-0cf3b43b0c21'::uuid, 35.6831457, 10.1044069), -- sanfour food
  ('88adb9cb-e638-42ef-b6b8-e8fca1e9dc78'::uuid, 35.6810119, 10.0900725), -- Titanic food
  ('8a00f5bc-9bfb-4294-aa04-56a4197bb6e1'::uuid, 35.6718608, 10.1027612), -- Soltan Kairouan (Sultan)
  ('2ad6d81b-e50a-4b35-8e18-06a27bc78ba1'::uuid, 35.6851379, 10.0947006)  -- Monoprix Kairouan 2
) AS c(id, lat, lng)
WHERE v.id = c.id
  AND (v.latitude IS DISTINCT FROM c.lat OR v.longitude IS DISTINCT FROM c.lng);


-- ── 2. vendors -> legacy mirror ─────────────────────────────────────────────
-- Only columns that genuinely duplicate between the two are mirrored.
-- Deliberately NOT mirrored: restaurants_legacy.is_blocked and
-- .commission_paid, which have no counterpart in vendors and are therefore
-- real legacy-owned data -- mirroring would destroy them. Phase 2 has to move
-- those two columns onto vendors before the legacy tables can be dropped.
--
-- UPDATE-only, never INSERT: a new vendor in a category legacy cannot
-- represent (flowers, pets, gifts, bakery, electronics) must NOT gain a legacy
-- row. Legacy stays a shrinking subset and is never grown by this trigger.

CREATE OR REPLACE FUNCTION public.sync_vendor_to_legacy()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.restaurants_legacy r SET
    name                = NEW.name,
    description         = NEW.description,
    image_url           = NEW.image_url,
    rating              = NEW.rating,
    review_count        = NEW.review_count,
    delivery_time_min   = NEW.delivery_time_min,
    delivery_fee        = NEW.delivery_fee,
    min_order           = NEW.min_order,
    categories          = NEW.categories,
    is_open             = NEW.is_open,
    latitude            = NEW.latitude,
    longitude           = NEW.longitude,
    opening_time        = NEW.opening_time,
    closing_time        = NEW.closing_time,
    auto_close_enabled  = NEW.auto_close_enabled,
    is_ghost_restaurant = NEW.is_ghost_restaurant
  WHERE r.id = NEW.id;

  -- supermarkets_legacy has no `categories` column.
  UPDATE public.supermarkets_legacy s SET
    name                = NEW.name,
    description         = NEW.description,
    image_url           = NEW.image_url,
    rating              = NEW.rating,
    review_count        = NEW.review_count,
    delivery_time_min   = NEW.delivery_time_min,
    delivery_fee        = NEW.delivery_fee,
    min_order           = NEW.min_order,
    is_open             = NEW.is_open,
    latitude            = NEW.latitude,
    longitude           = NEW.longitude,
    opening_time        = NEW.opening_time,
    closing_time        = NEW.closing_time,
    auto_close_enabled  = NEW.auto_close_enabled,
    is_ghost_restaurant = NEW.is_ghost_restaurant
  WHERE s.id = NEW.id;

  RETURN NULL; -- AFTER trigger
END;
$$;

DROP TRIGGER IF EXISTS sync_vendor_to_legacy ON public.vendors;
CREATE TRIGGER sync_vendor_to_legacy
  AFTER INSERT OR UPDATE ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_to_legacy();


-- ── 3. One-time reconciliation of every existing row ────────────────────────
-- The trigger only fires on future writes, so pull the two copies into
-- agreement now. vendors is authoritative by this point (step 1 corrected it).
-- No-op UPDATE on vendors is enough: it fires the trigger for every row.

UPDATE public.vendors SET id = id;
