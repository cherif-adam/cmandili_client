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
-- WARNING -- run this only once every driver has the app build of 2026-10-11
-- or later, the first one where the APP ITSELF reports "still here" every
-- two minutes and goes back online if the server switched it off.
--
-- This was learnt the hard way: with earlier builds the timestamp was only
-- refreshed by the background service (on a GPS movement, or on a heartbeat
-- that wrote nothing when the phone had no stored position), and that
-- service stops when location permission is missing or the phone maker
-- kills it. Drivers sitting in the open app were switched offline after 15
-- minutes and stopped receiving orders while their switch still showed
-- online.
--
-- If orders have stopped reaching drivers and this job is active, turn it
-- off first, then update the driver app:
--     select cron.unschedule('drivers_auto_offline_stale');
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
