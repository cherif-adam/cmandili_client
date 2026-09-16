-- ============================================================================
-- Repair: settlements_type_check
--
-- Symptom:
--   ERROR: 23514: check constraint "settlements_type_check" of relation
--   "settlements" is violated by some row
--
-- Cause:
--   20260805121032_prepaid_balance_model.sql was re-run against a database
--   that had already advanced past it. That migration installs a SIX-type
--   constraint, but the later 20260814090000_loyalty_at_checkout.sql widened
--   it to SEVEN by adding 'loyalty_subsidy' -- and its trigger has since
--   written rows of that type. Narrowing the constraint back therefore fails
--   against existing data.
--
--   Note the older migration must NOT be re-run for other reasons too: its
--   section 7 is a one-time cutover that zeroes every wallet and sets
--   is_blocked = TRUE on every driver and partner.
--
-- This migration only restores the constraint to the current allowed set.
-- It is idempotent, resets no balances, and blocks no accounts.
-- ============================================================================

ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_type_check;

ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_type_check
  CHECK (type IN (
    'order_earning',
    'commission_deduction',
    'payout',
    'collection',
    'manual_topup',
    'loyalty_subsidy'
  ));
