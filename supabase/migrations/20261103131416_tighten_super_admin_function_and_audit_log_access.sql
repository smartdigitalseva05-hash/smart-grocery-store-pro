-- Keep the Owner authorization helper callable by signed-in users only.
-- Anonymous users have no legitimate need to ask whether their identity is Super Admin.
REVOKE EXECUTE ON FUNCTION private.is_super_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_super_admin() TO authenticated;

-- Audit logs are privileged operational records; explicitly scope their policy
-- to authenticated users, with the existing MFA + active Super Admin predicate.
DROP POLICY IF EXISTS audit_admin ON public.audit_logs;
CREATE POLICY audit_admin
ON public.audit_logs
FOR SELECT
TO authenticated
USING (private.is_super_admin());