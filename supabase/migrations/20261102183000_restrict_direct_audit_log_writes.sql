-- Prevent direct client-authenticated audit log fabrication.
-- Trusted SECURITY DEFINER database routines (owned by postgres) continue
-- to write audit events; Owner UI only reads audit_logs.
REVOKE INSERT ON TABLE public.audit_logs FROM authenticated;
DROP POLICY IF EXISTS audit_admin_insert ON public.audit_logs;
