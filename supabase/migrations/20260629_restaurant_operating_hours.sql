-- Add optional operating hours + auto-close to restaurants and supermarkets.
-- opening_time: display only (partner must manually open each day — intentional)
-- closing_time: used by pg_cron to auto-close if auto_close_enabled = true
-- auto_close_enabled: opt-in per restaurant; default OFF (pure manual toggle unchanged)

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS auto_close_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS opening_time       TIME,
  ADD COLUMN IF NOT EXISTS closing_time       TIME;

ALTER TABLE public.supermarkets
  ADD COLUMN IF NOT EXISTS auto_close_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS opening_time       TIME,
  ADD COLUMN IF NOT EXISTS closing_time       TIME;

-- ── pg_cron auto-close job ────────────────────────────────────────────────────
-- pg_cron is available on all Supabase hosted projects.
-- The job runs every 5 minutes and closes any restaurant/supermarket whose
-- closing_time has passed in Tunisia local time (Africa/Tunis = UTC+1, no DST).
-- Auto-open is intentionally NOT done — partners must open manually each morning.

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'auto-close-restaurants',           -- unique job name (idempotent on re-run)
  '*/5 * * * *',                      -- every 5 minutes
  $$
    UPDATE public.restaurants
    SET    is_open = false
    WHERE  auto_close_enabled = true
      AND  is_open = true
      AND  closing_time IS NOT NULL
      AND  (NOW() AT TIME ZONE 'Africa/Tunis')::TIME >= closing_time;

    UPDATE public.supermarkets
    SET    is_open = false
    WHERE  auto_close_enabled = true
      AND  is_open = true
      AND  closing_time IS NOT NULL
      AND  (NOW() AT TIME ZONE 'Africa/Tunis')::TIME >= closing_time;
  $$
);
