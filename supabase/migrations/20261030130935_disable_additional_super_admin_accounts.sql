CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  active_admin_count integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.role = 'super_admin'::public.user_role THEN
      RAISE EXCEPTION 'Additional Super Admin accounts are disabled; use the existing Owner account'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- Only the account already authenticated as the primary Owner may retain
  -- the Super Admin role. No other account can be promoted to an administrator.
  IF NEW.role = 'super_admin'::public.user_role
     AND NEW.id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Additional Super Admin accounts are disabled'
      USING ERRCODE = '42501';
  END IF;

  IF OLD.role IS DISTINCT FROM NEW.role
     AND NOT private.is_super_admin() THEN
    RAISE EXCEPTION 'Role change forbidden'
      USING ERRCODE = '42501';
  END IF;

  IF OLD.is_active IS DISTINCT FROM NEW.is_active
     AND NOT private.is_super_admin() THEN
    RAISE EXCEPTION 'Account activation change forbidden'
      USING ERRCODE = '42501';
  END IF;

  IF OLD.role = 'super_admin'::public.user_role
     AND OLD.is_active = true
     AND (NEW.role <> 'super_admin'::public.user_role OR NEW.is_active = false) THEN
    SELECT count(*) INTO active_admin_count
    FROM public.profiles
    WHERE role = 'super_admin'::public.user_role
      AND is_active = true
      AND id <> OLD.id;

    IF active_admin_count = 0 THEN
      RAISE EXCEPTION 'Cannot disable or demote the last active super_admin'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$

