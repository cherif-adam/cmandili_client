-- user_addresses.latitude/longitude were assumed to already exist (present
-- in cmandili_schema.sql's reference definition) but were never actually
-- migrated onto the live table -- every saved address had no coordinate
-- storage at all. The client only ever hardcoded a placeholder coordinate at
-- read time instead. Add the real columns so the client can persist and
-- read a genuine per-address coordinate.
ALTER TABLE public.user_addresses
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION DEFAULT 0;
