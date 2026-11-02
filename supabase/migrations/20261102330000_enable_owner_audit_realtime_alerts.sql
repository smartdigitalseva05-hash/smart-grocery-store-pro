-- Allow the authenticated Owner dashboard to receive new audit-log rows.
-- Realtime still applies the audit_logs SELECT privilege and its AAL2+verified
-- TOTP RLS policy to each subscribed user.
DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime'
      AND schemaname='public'
      AND tablename='audit_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
  END IF;
END;
$migration$;
