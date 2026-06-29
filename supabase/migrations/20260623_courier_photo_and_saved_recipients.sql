-- ── 1. Package photo URL on orders ─────────────────────────────────────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS package_photo_url TEXT;

-- ── 2. Saved recipients table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS saved_recipients (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name           TEXT,
  phone          TEXT        NOT NULL,
  delivery_address JSONB,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE saved_recipients ENABLE ROW LEVEL SECURITY;

CREATE POLICY saved_recipients_select_own
  ON saved_recipients FOR SELECT USING (user_id = auth.uid());

CREATE POLICY saved_recipients_insert_own
  ON saved_recipients FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY saved_recipients_delete_own
  ON saved_recipients FOR DELETE USING (user_id = auth.uid());

-- ── 3. Supabase Storage bucket for package photos ────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('package-photos', 'package-photos', true)
  ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload
CREATE POLICY package_photos_upload
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'package-photos' AND auth.uid() IS NOT NULL);

-- Anyone can read (public bucket, needed for driver app to display photos)
CREATE POLICY package_photos_read
  ON storage.objects FOR SELECT
  USING (bucket_id = 'package-photos');

-- Owner can delete their own uploads
CREATE POLICY package_photos_delete_own
  ON storage.objects FOR DELETE
  USING (bucket_id = 'package-photos' AND auth.uid() IS NOT NULL);
