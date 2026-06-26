-- Add facture-specific columns to orders table.
-- bill_photo_url   : customer uploads a photo of their bill (optional)
-- bill_receipt_url : driver uploads the payment receipt after paying (optional)
-- bill_type        : 'topnet' | 'steg' | 'sonede' | 'autre'
-- bill_reference   : contract / reference number from the bill
-- bill_amount      : amount to be paid (cash collected from customer)
-- sender_phone     : customer phone for driver contact

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS bill_type        TEXT,
  ADD COLUMN IF NOT EXISTS bill_reference   TEXT,
  ADD COLUMN IF NOT EXISTS bill_amount      NUMERIC(12, 3),
  ADD COLUMN IF NOT EXISTS bill_photo_url   TEXT,
  ADD COLUMN IF NOT EXISTS bill_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS sender_phone     TEXT;

-- Allow 'facture' as a valid order_type value (no-op if CHECK constraint does
-- not exist, which is the common case with Supabase-managed tables).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'orders'
      AND constraint_name = 'orders_order_type_check'
  ) THEN
    ALTER TABLE orders
      DROP CONSTRAINT orders_order_type_check;
    ALTER TABLE orders
      ADD CONSTRAINT orders_order_type_check
      CHECK (order_type IN ('food','courier','supermarket','billPayment','facture'));
  END IF;
END $$;
