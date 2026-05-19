-- ============================================================================
-- CMANDILI MOBILE — Supabase migrations for payment methods, device tokens,
-- support tickets. Idempotent. Run in Supabase SQL editor.
-- ============================================================================

-- 1. payment_methods (tokenised card references; never store full PAN)
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_holder_name  TEXT NOT NULL,
  last_four         TEXT NOT NULL,
  expiry_date       TEXT NOT NULL,
  is_default        BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_methods_user_idx
  ON public.payment_methods(user_id);

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_payment_methods_select" ON public.payment_methods;
CREATE POLICY "own_payment_methods_select"
  ON public.payment_methods FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "own_payment_methods_insert" ON public.payment_methods;
CREATE POLICY "own_payment_methods_insert"
  ON public.payment_methods FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "own_payment_methods_update" ON public.payment_methods;
CREATE POLICY "own_payment_methods_update"
  ON public.payment_methods FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "own_payment_methods_delete" ON public.payment_methods;
CREATE POLICY "own_payment_methods_delete"
  ON public.payment_methods FOR DELETE
  USING (auth.uid() = user_id);


-- 2. device_tokens (FCM push tokens per user+device)
CREATE TABLE IF NOT EXISTS public.device_tokens (
  token       TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform    TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS device_tokens_user_idx
  ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_device_tokens_rw" ON public.device_tokens;
CREATE POLICY "own_device_tokens_rw"
  ON public.device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- 3. support_tickets (help & support form submissions)
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  subject     TEXT NOT NULL,
  message     TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_tickets_insert" ON public.support_tickets;
CREATE POLICY "own_tickets_insert"
  ON public.support_tickets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "own_tickets_select" ON public.support_tickets;
CREATE POLICY "own_tickets_select"
  ON public.support_tickets FOR SELECT
  USING (auth.uid() = user_id);
