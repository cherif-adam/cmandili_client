-- Add customer cancellation tracking columns to orders.
-- The existing notify_fcm_on_order_status trigger already handles
-- push notifications to customer + partner + driver on status='cancelled'.
-- Finance calculations already exclude cancelled orders (filter on 'delivered').
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_by        TEXT CHECK (cancelled_by IN ('customer', 'admin', 'system')),
  ADD COLUMN IF NOT EXISTS cancelled_at        TIMESTAMPTZ;

-- Auto-stamp cancelled_at when status transitions to 'cancelled'.
CREATE OR REPLACE FUNCTION public.handle_order_cancelled_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'cancelled' AND (OLD.status IS DISTINCT FROM 'cancelled') THEN
    NEW.cancelled_at = COALESCE(NEW.cancelled_at, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS order_cancelled_at ON public.orders;
CREATE TRIGGER order_cancelled_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_order_cancelled_at();
