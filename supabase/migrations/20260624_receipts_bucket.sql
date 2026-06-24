-- Create the public 'receipts' storage bucket for driver-uploaded payment receipts.
-- Drivers upload to receipts/{driver_id}/{order_id}_{timestamp}.jpg
-- The bucket is public so the customer app can display the receipt image
-- without needing a signed URL (consistent with how bill_photo_url works).

INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', true)
ON CONFLICT (id) DO NOTHING;

-- NOTE: Supabase runs PostgreSQL 15, which does NOT support
-- "CREATE POLICY IF NOT EXISTS" (that's PG17+ syntax).
-- Always guard policy creation with a DO $$ block checking pg_policies.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'drivers_upload_receipts'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "drivers_upload_receipts"
      ON storage.objects FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'receipts')
    $p$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'public_read_receipts'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "public_read_receipts"
      ON storage.objects FOR SELECT
      TO public
      USING (bucket_id = 'receipts')
    $p$;
  END IF;
END $$;
