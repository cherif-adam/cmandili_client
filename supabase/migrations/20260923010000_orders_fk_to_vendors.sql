-- ============================================================================
-- CMANDILI -- Repoint orders.restaurant_id / supermarket_id at `vendors`
--
-- THE BUG: checkout is impossible for every non-food, non-grocery category.
-- Verified by attempting a real flowers order in a rolled-back transaction,
-- built exactly the way checkout_screen.dart builds one:
--
--   ORDER INSERT: FAILED 23503 -- insert or update on table "orders"
--   violates foreign key constraint "orders_restaurant_id_fkey"
--
-- checkout writes the vendor's id into orders.restaurant_id (see
-- checkout_screen.dart:226 -- "a florist/pet/gift/bakery order rides the same
-- column"), but that column still points at restaurants_legacy, which only
-- holds the 11 food restaurants. So flowers, pets, gifts, bakery and
-- electronics orders are rejected by the database before a row can exist: no
-- order, no dispatch, no tracking. The delivery-fee and display work already
-- done for those categories was polish on a flow that could not complete.
--
-- THE FIX: point the FKs at `vendors`, which 20260922010000 already
-- established as the single source of truth for venue data, and which is a
-- strict superset of the legacy tables (29 venues vs 14).
--
-- SAFETY -- verified against live data before writing this:
--   orders with restaurant_id          : 99   would break against vendors: 0
--   orders with supermarket_id         :  0   would break against vendors: 0
--   order_items with food_item_id      : 118  would break against vendor_items: 0
-- Every id already resolves in the new target, so no row is orphaned and no
-- data migration is required.
--
-- SCOPE: only the two `orders` FKs, because those are what block checkout.
-- The other 12 FKs on the legacy tables (order_ratings, user_favorites,
-- food_item_option_groups, food_item_variants, supermarket_products,
-- restaurant_option_template_state, ...) are left alone deliberately: they do
-- not block any flow today, and repointing them is the larger consolidation
-- that also has to move restaurants_legacy.is_blocked / .commission_paid onto
-- vendors first -- those two columns have no counterpart there, so the legacy
-- tables cannot be dropped until they are migrated.
--
-- order_items.food_item_id is likewise NOT repointed here: vendor lines use
-- order_items.vendor_item_id (already FK'd to vendor_items), so the food path
-- keeps working unchanged and nothing about this migration needs it moved.
--
-- Idempotent -- safe to re-run.
-- ============================================================================

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_restaurant_id_fkey;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_restaurant_id_fkey
  FOREIGN KEY (restaurant_id) REFERENCES public.vendors(id);

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_supermarket_id_fkey;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_supermarket_id_fkey
  FOREIGN KEY (supermarket_id) REFERENCES public.vendors(id);
