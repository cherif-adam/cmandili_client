-- Migration: Add is_blocked to partners table
-- Purpose: Allow admin dashboard to block/unblock restaurant partners

ALTER TABLE public.partners
  ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT FALSE;

-- Allow service_role (used by admin dashboard API) to update is_blocked
GRANT UPDATE (is_blocked) ON public.partners TO service_role;
