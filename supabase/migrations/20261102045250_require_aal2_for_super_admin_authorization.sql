-- Super Admin authorization is only valid on an MFA-backed AAL2 session.
-- This helper is used by Owner RPCs, RLS policies and privileged triggers.
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
    );
$function$;
