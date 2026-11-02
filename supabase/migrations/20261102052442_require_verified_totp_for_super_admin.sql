-- Require both a fresh AAL2 session and a currently verified TOTP factor.
-- This prevents a still-valid AAL2 JWT from retaining Owner access after the
-- account's authenticator factor has been removed.
CREATE OR REPLACE FUNCTION private.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
    AND EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE id = auth.uid()
        AND role = 'super_admin'::public.user_role
        AND is_active = true
    )
    AND EXISTS (
      SELECT 1
      FROM auth.mfa_factors
      WHERE user_id = auth.uid()
        AND factor_type = 'totp'
        AND status = 'verified'
    );
$function$;
