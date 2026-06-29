-- Audit log table: records every admin write action for accountability
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_email TEXT        NOT NULL DEFAULT 'unknown',
  action_type TEXT        NOT NULL,
  target_type TEXT,
  target_id   TEXT,
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS audit_logs_admin_id_idx    ON public.audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS audit_logs_action_type_idx ON public.audit_logs(action_type);
CREATE INDEX IF NOT EXISTS audit_logs_created_at_idx  ON public.audit_logs(created_at DESC);

-- Only the service_role key can write; no RLS policies = no anon/user access
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
