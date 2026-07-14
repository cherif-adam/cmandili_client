-- ============================================================================
-- CMANDILI — Food item option groups (Sauce au choix, Garniture au choix,
-- Suppléments, etc.)
--
-- Adds three things:
--
--   1. `food_item_option_groups` — a reusable customization group owned by a
--      restaurant (e.g. "Sauce au choix", required, pick 1 to 4). Belongs to
--      a restaurant, NOT to a single food item, so the same group can be
--      linked to every makloub/cornet/mlawi item that restaurant sells
--      without duplicating rows per item. `is_required` is a generated
--      column derived from `min_selections` so the two can never disagree
--      ("Obligatoire" in the UI is exactly "min_selections > 0").
--
--   2. `food_item_options` — the individual choices inside a group (e.g.
--      "Harissa" — 0 TND, "Gruyère" — 6 TND). Each option has its own
--      add-on price, charged IN ADDITION to the food item's base price.
--
--   3. `food_item_option_group_links` — join table connecting food items to
--      the option groups that apply to them (many-to-many: one group can be
--      linked to many items, one item can have many groups). A trigger
--      guards that an item can only be linked to a group owned by the same
--      restaurant, so a bulk script can't accidentally cross-wire two
--      restaurants' menus.
--
-- Deliberately OUT of scope: single-choice "own absolute price" variants
-- (e.g. Mlawi's "Type au choix": Normal 5.40 / Mozzarella 6.60 / Cheddar
-- 7.70 TND — a REPLACEMENT price, not an add-on). That's a different pricing
-- shape and already has a schema: `food_item_variants`, added by migration
-- 20260509_item_variants_and_voice_notes.sql. That migration was written but
-- never pushed to the live project — the table does not exist yet in
-- production. No need to design it again; it just needs to be applied.
--
-- All idempotent — safe to re-run.
-- ============================================================================

-- ── 1. food_item_option_groups ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_item_option_groups (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id  UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,                     -- e.g. "Sauce au choix"
  min_selections INTEGER NOT NULL DEFAULT 0 CHECK (min_selections >= 0),
  max_selections INTEGER NOT NULL DEFAULT 1 CHECK (max_selections >= 1),
  is_required    BOOLEAN GENERATED ALWAYS AS (min_selections > 0) STORED,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (max_selections >= min_selections)
);

CREATE INDEX IF NOT EXISTS idx_food_item_option_groups_restaurant
  ON public.food_item_option_groups(restaurant_id, sort_order);

ALTER TABLE public.food_item_option_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS food_item_option_groups_public_read ON public.food_item_option_groups;
CREATE POLICY food_item_option_groups_public_read
  ON public.food_item_option_groups FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS food_item_option_groups_owner_write ON public.food_item_option_groups;
CREATE POLICY food_item_option_groups_owner_write
  ON public.food_item_option_groups FOR ALL
  USING (
    restaurant_id IN (
      SELECT entity_id FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type = 'restaurant'
    )
  )
  WITH CHECK (
    restaurant_id IN (
      SELECT entity_id FROM public.partners
      WHERE user_id = auth.uid()
        AND partner_type = 'restaurant'
    )
  );

-- ── 2. food_item_options ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_item_options (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      UUID NOT NULL REFERENCES public.food_item_option_groups(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,                       -- e.g. "Gruyère"
  price         DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (price >= 0),
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_item_options_group
  ON public.food_item_options(group_id, sort_order);

ALTER TABLE public.food_item_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS food_item_options_public_read ON public.food_item_options;
CREATE POLICY food_item_options_public_read
  ON public.food_item_options FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS food_item_options_owner_write ON public.food_item_options;
CREATE POLICY food_item_options_owner_write
  ON public.food_item_options FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.food_item_option_groups g
      WHERE g.id = food_item_options.group_id
        AND g.restaurant_id IN (
          SELECT entity_id FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.food_item_option_groups g
      WHERE g.id = food_item_options.group_id
        AND g.restaurant_id IN (
          SELECT entity_id FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
        )
    )
  );

-- ── 3. food_item_option_group_links ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_item_option_group_links (
  food_item_id UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
  group_id     UUID NOT NULL REFERENCES public.food_item_option_groups(id) ON DELETE CASCADE,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (food_item_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_food_item_option_group_links_group
  ON public.food_item_option_group_links(group_id);

ALTER TABLE public.food_item_option_group_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS food_item_option_group_links_public_read ON public.food_item_option_group_links;
CREATE POLICY food_item_option_group_links_public_read
  ON public.food_item_option_group_links FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS food_item_option_group_links_owner_write ON public.food_item_option_group_links;
CREATE POLICY food_item_option_group_links_owner_write
  ON public.food_item_option_group_links FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.food_item_option_groups g
      WHERE g.id = food_item_option_group_links.group_id
        AND g.restaurant_id IN (
          SELECT entity_id FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.food_item_option_groups g
      WHERE g.id = food_item_option_group_links.group_id
        AND g.restaurant_id IN (
          SELECT entity_id FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
        )
    )
  );

-- Guard: a food item can only be linked to an option group owned by the same
-- restaurant. Without this, a bulk-assignment script (or a stray admin
-- write) could silently wire one restaurant's items to another restaurant's
-- sauce/garniture group.
CREATE OR REPLACE FUNCTION public.guard_option_group_link_restaurant()
RETURNS TRIGGER AS $$
DECLARE
  item_restaurant_id  UUID;
  group_restaurant_id UUID;
BEGIN
  SELECT restaurant_id INTO item_restaurant_id
    FROM public.food_items WHERE id = NEW.food_item_id;
  SELECT restaurant_id INTO group_restaurant_id
    FROM public.food_item_option_groups WHERE id = NEW.group_id;

  IF item_restaurant_id IS DISTINCT FROM group_restaurant_id THEN
    RAISE EXCEPTION
      'food_item_option_group_links: food_item % (restaurant %) and group % (restaurant %) belong to different restaurants',
      NEW.food_item_id, item_restaurant_id, NEW.group_id, group_restaurant_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_guard_option_group_link_restaurant ON public.food_item_option_group_links;
CREATE TRIGGER trg_guard_option_group_link_restaurant
  BEFORE INSERT OR UPDATE ON public.food_item_option_group_links
  FOR EACH ROW EXECUTE FUNCTION public.guard_option_group_link_restaurant();
