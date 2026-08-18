-- ============================================================================
-- CMANDILI -- Schedule rotate_expired_offers() via pg_cron (P1)
--
-- rotate_expired_offers() already existed and does the right thing (clears
-- a dead assignment, marks the driver as passed, offers the next eligible
-- driver, or notifies the partner if the waterfall is exhausted) but was
-- never actually scheduled -- expired offers (assignment_expires_at passed,
-- driver_id still NULL) just sat orphaned forever. Confirmed via a real
-- orphaned test order (c5c62a7e..., created 2026-08-16) that never rolled
-- over to another driver.
--
-- No existing pg_cron job in this project runs faster than 1-minute
-- granularity (checked cron.job directly: disable_happy_hour is every
-- minute, auto-close-restaurants is every 5 *minutes*) -- there is no
-- pre-existing sub-minute job to mirror. pg_cron 1.6.4 (installed here)
-- supports an '<n> seconds' schedule string for sub-minute jobs directly,
-- used below. cron.schedule() upserts by job name, so this is safe to
-- re-apply.
-- ============================================================================

SELECT cron.schedule(
  'rotate-expired-offers',
  '10 seconds',
  $$SELECT public.rotate_expired_offers();$$
);
