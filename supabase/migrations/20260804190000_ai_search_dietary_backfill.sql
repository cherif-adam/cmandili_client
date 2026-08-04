-- ============================================================================
-- CMANDILI — Backfill is_spicy / is_vegetarian on food_items
--
-- Both flags were false on all 302 available food_items, so AI search returned
-- zero results for any spicy/vegetarian query: the Edge Function filters on
-- .eq("is_spicy", true) / .eq("is_vegetarian", true), which matched nothing.
--
-- Applied live on 2026-08-04 via `supabase db query --linked`; this file exists
-- to record that change in migration history (marked applied via
-- `supabase migration repair`, NOT re-run against production).
--
-- Both statements are idempotent — re-running only re-sets already-true rows.
--
-- Matching is name/description regex, so it is a heuristic, not ground truth.
-- Two deliberate choices:
--
--   * 'hot ' is NOT a spicy token. It matched "Hot Dog" (3 rows), which is not
--     spicy. Substring traps like this are why the token list is explicit.
--
--   * is_vegetarian requires POSITIVE evidence (a veg term) rather than mere
--     absence of a meat term. The looser "no meat token found" reading matched
--     119 rows, including plain "Chapati", "Cornet" and "Calzone Primavera" —
--     items whose names simply do not state their contents, and which in
--     Tunisia normally arrive with thon or escalope. Telling someone with a
--     dietary restriction that a meat dish is meat-free is a worse failure
--     than omitting a genuinely vegetarian one, so unknown stays false.
--     Earlier passes of this list also wrongly caught 'kebda' (liver),
--     'saucisson' and 'Fruits de Mer'; those are now excluded explicitly.
--
--   * Salade Tunisienne / Mechouia / de Riz are excluded by decision — all
--     three are traditionally served with tuna or egg in Tunisia and the names
--     do not say. The 'salade' token is therefore absent from the positive
--     list entirely, so salad items added later inherit the same caution.
--
-- Result: 25 rows spicy, 16 rows vegetarian, 0 salads.
-- ============================================================================

-- Spicy: 25 rows.
UPDATE food_items SET is_spicy = true
WHERE is_available
  AND lower(coalesce(name, '') || ' ' || coalesce(description, ''))
      ~ '(merguez|harissa|kafteji|(é|e)pic(é|e)|spicy|chili|piment|7arra)';

-- Vegetarian: 16 rows. Positive veg signal AND no meat token AND not a drink.
UPDATE food_items SET is_vegetarian = true
WHERE is_available
  AND lower(coalesce(name, '') || ' ' || coalesce(description, ''))
      ~ '(omlette|omelette|oeuf|fromage|cheese|margherita|margarita|l(é|e)gume|v(é|e)g(é|e)|falafel|lablabi|chakchouka|hummus|houmous|frites|patate)'
  AND lower(coalesce(name, '') || ' ' || coalesce(description, ''))
      !~ '(viande|steak|escalope|cordon|jambon|thon|poulet|chicken|merguez|kebab|tuna|salami|pepperoni|bacon|charcut|nugget|kabab|chawarma|shawarma|paella|crevette|poisson|agneau|boeuf|dinde|saucis|hot ?dog|burger|mixte|ojja|allouch|kammounia|osbane|kebda|kefta|fruits de mer|sicilien|foie|gambas|calamar|seiche|poulpe|mortadelle|pastrami|slice)'
  AND category !~* '(boisson|drink)';
