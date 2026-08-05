-- ============================================================================
-- CMANDILI — Backfill min_selections = 0 on existing Sauce/Garniture groups
--
-- "Garniture au choix" (and "Sauce au choix") still showed as "Obligatoire"
-- on device: the trigger change in 20260720190000 only covers newly-
-- bootstrapped restaurants. The one-off backfill for the 8 EXISTING groups
-- (supabase/scripts/20260720_optional_sauce_garniture.sql) was drafted
-- 2026-07-20 but never actually run against production until now.
--
-- Applied live on 2026-08-05 via `supabase db query --linked`; this file
-- exists to record that change in migration history (marked applied via
-- `supabase migration repair`, NOT re-run against production).
--
-- Idempotent — the WHERE excludes rows already at min_selections = 0, so a
-- future `db reset` / re-run only affects rows that still need it.
--
-- Result: 8 rows updated (4 Sauce au choix + 4 Garniture au choix, across the
-- same 4 restaurants). is_required is a generated column (min_selections > 0)
-- so it flipped to false automatically for all 8 — nothing else changed.
-- ============================================================================

UPDATE public.food_item_option_groups
SET min_selections = 0
WHERE name IN ('Sauce au choix', 'Garniture au choix')
  AND min_selections <> 0;
