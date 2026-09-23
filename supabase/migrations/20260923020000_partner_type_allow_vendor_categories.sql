-- ============================================================================
-- CMANDILI -- Allow the generic vendor categories in partners.partner_type
--
-- The partner app has offered seven shop types since the multi-category work
-- (kPartnerTypes in partner_model.dart: restaurant, supermarket, bakery,
-- flowers, pets, gifts, electronics), and branches on the value in several
-- load-bearing places:
--
--   menu_provider.dart:19-30     picks which catalogue table to read --
--                                'restaurant' -> food_items, generic ->
--                                vendor_items, else grocery_items
--   add_edit_item_screen.dart:76 picks which table a new item is written to
--   menu_screen.dart:313         wording ("dish" vs "product")
--   partner_model.dart:9         maps the type onto vendors.category
--
-- But the database still only permitted the two legacy values:
--
--   CHECK (partner_type = ANY (ARRAY['restaurant', 'supermarket']))
--
-- so any attempt to store the real category fails with 23514, and a partner
-- registering a florist/pet/gift/bakery/electronics shop could never have the
-- correct type persisted. Forcing 'restaurant' instead (which is what the
-- constraint leaves you with) makes menu_provider read food_items, where a
-- generic vendor has no rows -- the partner opens their Menu tab and sees
-- "No items yet" even though their catalogue exists in vendor_items.
--
-- Widening to match kPartnerTypes exactly. Kept as an explicit allowlist
-- rather than dropping the constraint: it still catches typos, and a category
-- added in the app in future should be a deliberate schema change, not a
-- silent free-text insert.
--
-- Idempotent -- safe to re-run.
-- ============================================================================

ALTER TABLE public.partners DROP CONSTRAINT IF EXISTS partners_partner_type_check;
ALTER TABLE public.partners
  ADD CONSTRAINT partners_partner_type_check
  CHECK (partner_type = ANY (ARRAY[
    'restaurant'::text,
    'supermarket'::text,
    'bakery'::text,
    'flowers'::text,
    'pets'::text,
    'gifts'::text,
    'electronics'::text
  ]));
