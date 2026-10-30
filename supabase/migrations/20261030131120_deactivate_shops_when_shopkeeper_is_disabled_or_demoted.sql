CREATE OR REPLACE FUNCTION public.guard_shop_activation_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_service_role boolean := coalesce(auth.jwt() ->> 'role', '') = 'service_role';
  v_expiry_job boolean := coalesce(current_setting('app.subscription_expiry_job', true), 'false') = 'true';
  v_profile_deactivation boolean := coalesce(current_setting('app.owner_profile_deactivation', true), 'false') = 'true';
  v_owner_status_rpc boolean := coalesce(current_setting('app.owner_shop_status_rpc', true), 'false') = 'true';
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_service_role THEN RETURN NEW; END IF;
    NEW.is_active := false;
    NEW.status := 'inactive'::public.shop_status;
    NEW.subscription_plan_id := NULL;
    NEW.subscription_expires_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.is_active IS NOT DISTINCT FROM NEW.is_active
     AND OLD.status IS NOT DISTINCT FROM NEW.status
     AND OLD.subscription_plan_id IS NOT DISTINCT FROM NEW.subscription_plan_id
     AND OLD.subscription_expires_at IS NOT DISTINCT FROM NEW.subscription_expires_at THEN
    RETURN NEW;
  END IF;

  IF v_service_role THEN RETURN NEW; END IF;

  IF v_expiry_job OR v_profile_deactivation THEN
    IF NEW.is_active = false
       AND NEW.status = 'inactive'::public.shop_status
       AND NEW.subscription_plan_id IS NOT DISTINCT FROM OLD.subscription_plan_id
       AND NEW.subscription_expires_at IS NOT DISTINCT FROM OLD.subscription_expires_at THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Trusted deactivation process may only deactivate a shop without changing its subscription'
      USING ERRCODE = '42501';
  END IF;

  IF v_owner_status_rpc THEN
    IF NEW.subscription_plan_id IS DISTINCT FROM OLD.subscription_plan_id
       OR NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
      RAISE EXCEPTION 'Owner status action cannot alter subscription plan or expiry'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.is_active IS DISTINCT FROM (NEW.status = 'active'::public.shop_status) THEN
      RAISE EXCEPTION 'Shop active flag and status must agree'
        USING ERRCODE = '23514';
    END IF;

    IF NEW.is_active THEN
      IF NOT EXISTS (
        SELECT 1
        FROM public.shop_subscriptions ss
        JOIN public.payments p ON p.id = ss.payment_id
        WHERE ss.shop_id = NEW.id
          AND ss.plan_id = NEW.subscription_plan_id
          AND ss.ends_at = NEW.subscription_expires_at
          AND ss.status = 'active'::public.subscription_status
          AND ss.ends_at > now()
          AND p.status = 'success'::public.payment_status
          AND p.verified = true
      ) THEN
        RAISE EXCEPTION 'Shop activation requires a verified successful active subscription'
          USING ERRCODE = '55000';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Only the verified payment process, expiry scheduler, or protected Owner status action can change shop activation fields'
    USING ERRCODE = '42501';
END;
$function$;

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

  -- Disabling or demoting a shopkeeper also disables every shop they own.
  -- Reactivation never happens automatically; the Owner must use the protected
  -- status RPC, which rechecks a verified active subscription.
  IF (OLD.role = 'shopkeeper'::public.user_role AND NEW.role <> 'shopkeeper'::public.user_role)
     OR (OLD.is_active = true AND NEW.is_active = false) THEN
    PERFORM set_config('app.owner_profile_deactivation', 'true', true);
    UPDATE public.shops
    SET is_active = false,
        status = 'inactive'::public.shop_status,
        updated_at = now()
    WHERE owner_id = OLD.id
      AND (is_active = true OR status <> 'inactive'::public.shop_status);
    PERFORM set_config('app.owner_profile_deactivation', 'false', true);
  END IF;

  RETURN NEW;
END;
$function$;