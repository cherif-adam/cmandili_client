-- Drop the admin_dispatch_order RPC that was created in 20260628_admin_dispatch.sql.
-- Manual driver assignment is not supported; orders are always dispatched through
-- the automatic waterfall (next_eligible_driver / offer_order_to_driver).
DROP FUNCTION IF EXISTS public.admin_dispatch_order(UUID, UUID, INT);
