-- ============================================================================
-- CMANDILI — Auto-apply customization templates to new food items
--
-- Makes 01_bulk_apply_customization_templates.sql's one-shot logic automatic:
-- a new restaurant's first matching item, or a new matching item on an
-- existing restaurant, gets the template the instant it's created — no
-- manual re-run. Same family matching + template content as that script,
-- extracted into one function (apply_customization_template_to_item) so the
-- trigger below and any future manual run share one source of truth.
--
-- Deletion safety: everything except restaurant-scoped GROUP CREATION is
-- already safe by construction — an item's own links/variants and a
-- surviving group's own options are each written exactly once, at first
-- creation, and this trigger never re-fires for a row that already exists.
-- Group creation is the one thing that re-runs on every new matching item
-- forever (it has to, to find the ids to link to), so it's the one thing
-- that needs an explicit "don't recreate what was deliberately deleted"
-- guard: restaurant_option_template_state, a one-row-per-restaurant
-- tombstone written once on first bootstrap. After that, a missing group is
-- never recreated — new items just link to whichever of the 3 still exist.
-- Backfilled below for restaurants already bootstrapped by the 2026-07-19
-- manual run (or earlier hand-seeded ones), so this is retroactive.
--
-- The trigger never blocks the food_items insert itself: any error in the
-- template logic is caught and logged (RAISE WARNING), never propagated —
-- same defensive shape as the cmandili_rotate_offers cron job
-- (20260510_assignment_and_distance.sql).
--
-- NOT applied — review only, per request.
-- ============================================================================

-- ── 1. Tombstone: has this restaurant ever received the auto-template? ─────
CREATE TABLE IF NOT EXISTS public.restaurant_option_template_state (
  restaurant_id   UUID PRIMARY KEY REFERENCES public.restaurants(id) ON DELETE CASCADE,
  bootstrapped_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.restaurant_option_template_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS restaurant_option_template_state_public_read ON public.restaurant_option_template_state;
CREATE POLICY restaurant_option_template_state_public_read
  ON public.restaurant_option_template_state FOR SELECT
  USING (TRUE);
-- No write policy — only apply_customization_template_to_item() (SECURITY
-- DEFINER, owned by the migration role) writes this table, same pattern as
-- trg_guard_option_group_link_restaurant.

-- Backfill: retroactively tombstone any restaurant that already has at least
-- one of the 3 named groups (2026-07-19 bulk run, or an earlier hand-seeded
-- restaurant). Restaurants with NONE of the 3 are deliberately left
-- un-tombstoned — they still get their legitimate first-ever bootstrap.
INSERT INTO public.restaurant_option_template_state (restaurant_id)
SELECT DISTINCT restaurant_id
FROM public.food_item_option_groups
WHERE name IN ('Sauce au choix', 'Garniture au choix', 'Suppléments')
ON CONFLICT (restaurant_id) DO NOTHING;

-- ── 2. Single source of truth: apply the template to one item ──────────────
CREATE OR REPLACE FUNCTION public.apply_customization_template_to_item(p_food_item_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_item                  RECORD;
  v_n_item                TEXT;
  v_family                TEXT;
  v_n_family_matches      INT;
  v_already_bootstrapped  BOOLEAN;
  v_sauce_id              UUID;
  v_garniture_id          UUID;
  v_supp_id               UUID;
  v_delta_mozzarella CONSTANT DOUBLE PRECISION := 1.20;
  v_delta_cheddar    CONSTANT DOUBLE PRECISION := 2.30;
BEGIN
  SELECT fi.id, fi.restaurant_id, fi.name, fi.price, r.name AS restaurant_name
    INTO v_item
    FROM public.food_items fi
    JOIN public.restaurants r ON r.id = fi.restaurant_id
    WHERE fi.id = p_food_item_id;

  IF NOT FOUND THEN
    RETURN 'skipped_not_found';
  END IF;

  -- Same accent-stripped, lowercased normalization as the bulk script.
  v_n_item := lower(translate(v_item.name,
    'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ',
    'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'
  ));

  v_n_family_matches :=
      (v_n_item ~ 'maklou')::int
    + (v_n_item ~ 'cornet')::int
    + (v_n_item ~ 'malfou')::int
    + (v_n_item ~ 'farcie|baguette')::int
    + (v_n_item ~ 'tabouna|tabuna')::int
    + (v_n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou')::int
    + (v_n_item ~ 'calzone')::int;

  IF v_n_family_matches = 0 THEN
    RETURN 'skipped_no_match';
  END IF;

  IF v_n_family_matches > 1 THEN
    RAISE WARNING 'apply_customization_template_to_item: item % ("%") matches % family patterns — ambiguous, not modified',
      p_food_item_id, v_item.name, v_n_family_matches;
    RETURN 'skipped_ambiguous';
  END IF;

  v_family := CASE
    WHEN v_n_item ~ 'maklou'                      THEN 'makloub'
    WHEN v_n_item ~ 'cornet'                       THEN 'cornet'
    WHEN v_n_item ~ 'malfou'                       THEN 'malfouf'
    WHEN v_n_item ~ 'farcie|baguette'               THEN 'baguette_farcie'
    WHEN v_n_item ~ 'tabouna|tabuna'                 THEN 'tabouna'
    WHEN v_n_item ~ 'm[ae]?l[ae]?w|mlaou|melaou'      THEN 'mlawi'
    WHEN v_n_item ~ 'calzone'                          THEN 'calzone'
  END;

  IF lower(v_item.restaurant_name) = ANY (ARRAY['food', 'plan', 'restaurant']) THEN
    RETURN 'skipped_test_restaurant';
  END IF;

  IF v_item.price = 0 THEN
    RAISE WARNING 'apply_customization_template_to_item: item % ("%") is priced at 0 — needs manual review, not modified',
      p_food_item_id, v_item.name;
    RETURN 'skipped_zero_price';
  END IF;

  -- Rule 3 from the bulk script: skip anything already customized, by
  -- anyone — this trigger, a previous manual run, or the partner by hand.
  IF EXISTS (SELECT 1 FROM public.food_item_option_group_links WHERE food_item_id = p_food_item_id)
     OR EXISTS (SELECT 1 FROM public.food_item_variants WHERE food_item_id = p_food_item_id) THEN
    RETURN 'skipped_already_customized';
  END IF;

  -- Serialize concurrent bootstraps of the SAME restaurant (the AI
  -- menu-photo scanner fires several inserts back-to-back for a brand-new
  -- restaurant) so two items can't each see "no group yet" and both create
  -- one. Transaction-scoped — releases automatically, nothing to clean up.
  PERFORM pg_advisory_xact_lock(hashtext('restaurant_option_template'), hashtext(v_item.restaurant_id::text));

  SELECT EXISTS (
    SELECT 1 FROM public.restaurant_option_template_state WHERE restaurant_id = v_item.restaurant_id
  ) INTO v_already_bootstrapped;

  -- ── Bootstrap-or-reuse the restaurant's 3 template groups ─────────────────
  SELECT id INTO v_sauce_id FROM public.food_item_option_groups
    WHERE restaurant_id = v_item.restaurant_id AND name = 'Sauce au choix';
  IF v_sauce_id IS NULL AND NOT v_already_bootstrapped THEN
    INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
      VALUES (v_item.restaurant_id, 'Sauce au choix', 1, 4, 0)
      RETURNING id INTO v_sauce_id;
    INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
      (v_sauce_id, 'Harissa', 0, 0),
      (v_sauce_id, 'Mayonnaise', 0, 1),
      (v_sauce_id, 'Sauce Algérienne', 0, 2),
      (v_sauce_id, 'Salade Mechouia', 0, 3);
  END IF;

  SELECT id INTO v_garniture_id FROM public.food_item_option_groups
    WHERE restaurant_id = v_item.restaurant_id AND name = 'Garniture au choix';
  IF v_garniture_id IS NULL AND NOT v_already_bootstrapped THEN
    INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
      VALUES (v_item.restaurant_id, 'Garniture au choix', 1, 3, 1)
      RETURNING id INTO v_garniture_id;
    INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
      (v_garniture_id, 'Laitue', 0, 0),
      (v_garniture_id, 'Tomate', 0, 1),
      (v_garniture_id, 'Oignon', 0, 2);
  END IF;

  SELECT id INTO v_supp_id FROM public.food_item_option_groups
    WHERE restaurant_id = v_item.restaurant_id AND name = 'Suppléments';
  IF v_supp_id IS NULL AND NOT v_already_bootstrapped THEN
    INSERT INTO public.food_item_option_groups (restaurant_id, name, min_selections, max_selections, sort_order)
      VALUES (v_item.restaurant_id, 'Suppléments', 0, 4, 2)
      RETURNING id INTO v_supp_id;
    INSERT INTO public.food_item_options (group_id, name, price, sort_order) VALUES
      (v_supp_id, 'Gruyère', 6.0, 0),
      (v_supp_id, 'Fromage Arbi', 4.8, 1),
      (v_supp_id, 'Cheddar', 3.6, 2),
      (v_supp_id, 'Frisco', 6.0, 3);
  END IF;

  IF NOT v_already_bootstrapped THEN
    INSERT INTO public.restaurant_option_template_state (restaurant_id)
      VALUES (v_item.restaurant_id)
      ON CONFLICT (restaurant_id) DO NOTHING;
  END IF;

  -- Link to whichever of the 3 groups currently exist. A NULL id here means
  -- "already bootstrapped once, and the partner has since deleted this
  -- specific group" — never recreated, never linked.
  INSERT INTO public.food_item_option_group_links (food_item_id, group_id, sort_order)
    SELECT p_food_item_id, g.id, g.sort_order
    FROM (VALUES (v_sauce_id, 0), (v_garniture_id, 1), (v_supp_id, 2)) AS g(id, sort_order)
    WHERE g.id IS NOT NULL
  ON CONFLICT DO NOTHING;

  -- Template B: mlawi/calzone additionally get "Type au choix" variants,
  -- computed from this item's own price. Independent of the groups above,
  -- and independently deletion-safe: only ever runs once, at this item's
  -- INSERT, never re-fires for an existing row.
  IF v_family IN ('mlawi', 'calzone') THEN
    INSERT INTO public.food_item_variants (food_item_id, name, price, sort_order) VALUES
      (p_food_item_id, 'Normal', v_item.price, 0),
      (p_food_item_id, 'Mozzarella', round((v_item.price + v_delta_mozzarella)::numeric, 2)::double precision, 1),
      (p_food_item_id, 'Cheddar', round((v_item.price + v_delta_cheddar)::numeric, 2)::double precision, 2);
  END IF;

  RETURN 'applied';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_customization_template_to_item(UUID) FROM PUBLIC;
-- Triggers don't need an EXECUTE grant to fire — this only blocks direct
-- calls (e.g. PostgREST's /rpc/apply_customization_template_to_item) from
-- arbitrary authenticated/anon callers passing someone else's food_item_id.

-- ── 3. AFTER INSERT trigger — never blocks the item insert itself ──────────
CREATE OR REPLACE FUNCTION public.trg_apply_customization_template()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  BEGIN
    PERFORM public.apply_customization_template_to_item(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'trg_apply_customization_template: auto-template failed for food_item % — %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_apply_customization_template ON public.food_items;
CREATE TRIGGER auto_apply_customization_template
  AFTER INSERT ON public.food_items
  FOR EACH ROW EXECUTE FUNCTION public.trg_apply_customization_template();
