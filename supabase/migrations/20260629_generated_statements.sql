-- Stores generated driver/restaurant statements for shareable verification links.
-- Each row is immutable after creation (snapshot of orders at generation time).
CREATE TABLE IF NOT EXISTS public.generated_statements (
  id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_code   TEXT            NOT NULL UNIQUE,
  entity_type      TEXT            NOT NULL CHECK (entity_type IN ('driver', 'restaurant')),
  entity_id        TEXT            NOT NULL,
  entity_name      TEXT            NOT NULL,
  entity_phone     TEXT,
  date_from        DATE            NOT NULL,
  date_to          DATE            NOT NULL,
  generated_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  order_count      INT             NOT NULL DEFAULT 0,
  total_amount     NUMERIC(12, 3)  NOT NULL DEFAULT 0,
  total_commission NUMERIC(12, 3)  NOT NULL DEFAULT 0,
  -- Snapshot of orders at generation time — immutable for dispute-proof verification.
  -- Fields per order: { id, date, label, amount, commission }
  orders_snapshot  JSONB           NOT NULL DEFAULT '[]'
);

CREATE INDEX IF NOT EXISTS generated_statements_ref_idx    ON public.generated_statements(reference_code);
CREATE INDEX IF NOT EXISTS generated_statements_entity_idx ON public.generated_statements(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS generated_statements_date_idx   ON public.generated_statements(generated_at DESC);

-- Service_role only — no RLS policies means no row access for anon/authenticated roles.
-- The public /releve/[ref] page reads this via the server-side service_role key only.
ALTER TABLE public.generated_statements ENABLE ROW LEVEL SECURITY;
