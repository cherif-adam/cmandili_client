-- ============================================================================
-- CMANDILI — "Sauce au choix" / "Garniture au choix" become optional for
-- newly-bootstrapped restaurants too
--
-- Customers must be able to add an item with zero selections — no forced
-- choices. This redefines apply_customization_template_to_item() (from
-- 20260720120000_auto_apply_customization_templates.sql — live, its header
-- comment claiming "NOT applied" is stale: the function and its trigger
-- auto_apply_customization_template are both confirmed live and enabled)
-- so any restaurant bootstrapped FROM NOW ON gets Sauce au choix (0-4) and
-- Garniture au choix (0-3) as optional, matching Suppléments (already 0-4).
-- Only the two min_selections literals change, 1 -> 0; max_selections,
-- matching, family-detection, and every other rule are untouched.
--
-- Existing restaurants already bootstrapped are NOT covered by this
-- function change (it only runs on first bootstrap of a restaurant, guarded
-- by restaurant_option_template_state) — see the companion one-off script
-- supabase/scripts/20260720_optional_sauce_garniture.sql for those.
--
-- No "Aucun" placeholder option — optional is expressed purely via
-- min_selections = 0, same as Suppléments.
--
-- NOT applied — for review. Apply the same way as the original migration,
-- once approved: `supabase db query --linked -f <this file>` then
-- `supabase migration repair --status applied 20260720190000`.
-- ============================================================================

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
      VALUES (v_item.restaurant_id, 'Sauce au choix', 0, 4, 0)
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
      VALUES (v_item.restaurant_id, 'Garniture au choix', 0, 3, 1)
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
