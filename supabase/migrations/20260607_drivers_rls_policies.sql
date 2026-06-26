-- Fix: drivers table was missing RLS policies entirely.
-- The driver app updates is_online, current_lat, current_lng via drivers.id,
-- but auth.uid() = drivers.user_id (not drivers.id), so policies must join
-- through user_id.

ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- SELECT: a driver can read their own row (used by currentDriverIdProvider)
DROP POLICY IF EXISTS "drivers_select_own" ON public.drivers;
CREATE POLICY "drivers_select_own"
  ON public.drivers FOR SELECT
  USING (user_id = auth.uid());

-- UPDATE: a driver can update their own row (is_online, GPS coordinates)
DROP POLICY IF EXISTS "drivers_update_own" ON public.drivers;
CREATE POLICY "drivers_update_own"
  ON public.drivers FOR UPDATE
  USING (user_id = auth.uid());

-- INSERT: allow creating the driver record on first login
-- (currentDriverIdProvider inserts with user_id = auth.uid() when no row exists)
DROP POLICY IF EXISTS "drivers_insert_own" ON public.drivers;
CREATE POLICY "drivers_insert_own"
  ON public.drivers FOR INSERT
  WITH CHECK (user_id = auth.uid());
