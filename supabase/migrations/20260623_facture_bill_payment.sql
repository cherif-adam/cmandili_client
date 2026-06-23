-- ── 1. Bill-payment columns on orders ───────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS bill_type       TEXT,          -- topnet | steg | sonede | autre
  ADD COLUMN IF NOT EXISTS bill_reference  TEXT,          -- reference / contract number
  ADD COLUMN IF NOT EXISTS bill_amount     NUMERIC(10,3), -- amount driver collects and pays
  ADD COLUMN IF NOT EXISTS bill_photo_url  TEXT,          -- optional photo of the bill (customer)
  ADD COLUMN IF NOT EXISTS receipt_photo_url TEXT;        -- proof of payment (driver uploads)

-- ── 2. Widen order_type CHECK constraint to include 'facture' ───────────────
-- Drop any existing CHECK on order_type (name may vary), then re-add a wider one.
DO $$
DECLARE
  v_cname TEXT;
BEGIN
  SELECT conname INTO v_cname
  FROM pg_constraint
  WHERE conrelid = 'public.orders'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%order_type%'
  LIMIT 1;
  IF v_cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.orders DROP CONSTRAINT ' || quote_ident(v_cname);
  END IF;
END $$;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_order_type_valid
  CHECK (order_type IN ('food', 'courier', 'supermarket', 'facture'));

-- ── 3. RLS: allow the assigned driver to update receipt_photo_url ────────────
-- Safe to run even if a policy with this name already exists.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'orders' AND policyname = 'orders_driver_update_own'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY orders_driver_update_own
        ON public.orders FOR UPDATE
        USING  (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()))
        WITH CHECK (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()))
    $policy$;
  END IF;
END $$;

-- ── 4. Storage bucket for driver receipt photos ──────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('receipts', 'receipts', true)
  ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'receipts_driver_upload'
  ) THEN
    EXECUTE $p$
      CREATE POLICY receipts_driver_upload
        ON storage.objects FOR INSERT
        WITH CHECK (bucket_id = 'receipts' AND auth.uid() IS NOT NULL)
    $p$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'receipts_public_read'
  ) THEN
    EXECUTE $p$
      CREATE POLICY receipts_public_read
        ON storage.objects FOR SELECT
        USING (bucket_id = 'receipts')
    $p$;
  END IF;
END $$;
