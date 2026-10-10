-- Switch drivers offline when their phone has gone quiet
-- ============================================================================
-- NOT EXECUTED. Optional safety net -- read the WARNING before running.
--
-- Dispatch (next_eligible_driver) offers an order to any driver whose
-- drivers.is_online is TRUE. Nothing on the server ever turns that flag off:
-- only the driver's own switch does. So a driver whose phone died, who
-- force-stopped or uninstalled the app, or who lost network for good, stays
-- "online" forever and keeps being offered orders -- each one costing the
-- customer the 30 s it takes rotate_expired_offers to move on.
--
-- The driver app now covers what an app can: logging out sets the driver
-- offline, a failed "go offline" is retried until confirmed, and an offer
-- that reaches an offline driver is passed on at once. What an app cannot
-- do is report that it is no longer running. This job does that from the
-- server side: every minute, any "online" driver with no sign of life for
-- 15 minutes is switched off.
--
-- "Sign of life" is drivers.last_location_update, written on every GPS fix
-- and by the background service's heartbeat every 4 minutes even when the
-- driver is standing still. 15 minutes is the same threshold the unapplied
-- next_eligible_driver fix in scripts/20260926_fix_phantom_block_and_stale_
-- online.sql uses, and comfortably more than three missed heartbeats.
--
-- WARNING -- run this only once every driver has an app build with the
-- 4-minute heartbeat (driver commit 3255e20, 2026-09-29, or later). An older
-- build writes its position only when the driver MOVES, so a driver waiting
-- outside a restaurant would be switched offline after 15 minutes while
-- their app still shows them online, and they would stop receiving orders.
--
-- Safe to re-run: cron.schedule() replaces a job with the same name.
-- To remove it later:  select cron.unschedule('drivers_auto_offline_stale');

select cron.schedule(
  'drivers_auto_offline_stale',
  '* * * * *',
  $job$
    update public.drivers
       set is_online = false
     where is_online = true
       and (last_location_update is null
            or last_location_update < now() - interval '15 minutes');
  $job$
);
