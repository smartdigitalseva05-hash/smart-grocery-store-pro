CREATE OR REPLACE FUNCTION public.guard_shop_activation_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_service_role boolean := coalesce(auth.jwt() ->> 'role', '') = 'service_role';
  v_expiry_job boolean := coalesce(current_setting('app.subscription_expiry_job', true), 'false') = 'true';
  v_owner_status_rpc boolean := coalesce(current_setting('app.owner_shop_status_rpc', true), 'false') = 'true';
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_service_role THEN
      RETURN NEW;
    END IF;
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

  IF v_service_role THEN
    RETURN NEW;
  END IF;

  IF v_expiry_job THEN
    IF NEW.is_active = false
       AND NEW.status = 'inactive'::public.shop_status
       AND NEW.subscription_plan_id IS NOT DISTINCT FROM OLD.subscription_plan_id
       AND NEW.subscription_expires_at IS NOT DISTINCT FROM OLD.subscription_expires_at THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Subscription expiry job may only deactivate expired shops'
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
$function$


CREATE OR REPLACE FUNCTION public.owner_set_shop_status(p_shop_id uuid, p_status shop_status)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_old public.shops%rowtype;
  v_active boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_super_admin() THEN
    RAISE EXCEPTION 'Only active super_admin can change shop status'
      USING ERRCODE = '42501';
  END IF;

  IF p_shop_id IS NULL OR p_status IS NULL THEN
    RAISE EXCEPTION 'Shop ID and status are required'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_old
  FROM public.shops
  WHERE id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shop not found' USING ERRCODE = 'P0002';
  END IF;

  v_active := (p_status = 'active'::public.shop_status);

  IF v_active AND NOT EXISTS (
    SELECT 1
    FROM public.shop_subscriptions ss
    JOIN public.payments p ON p.id = ss.payment_id
    WHERE ss.shop_id = p_shop_id
      AND ss.plan_id = v_old.subscription_plan_id
      AND ss.ends_at = v_old.subscription_expires_at
      AND ss.status = 'active'::public.subscription_status
      AND ss.ends_at > now()
      AND p.status = 'success'::public.payment_status
      AND p.verified = true
  ) THEN
    RAISE EXCEPTION 'Shop activation requires a verified successful active subscription'
      USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.owner_shop_status_rpc', 'true', true);

  UPDATE public.shops
  SET status = p_status,
      is_active = v_active,
      updated_at = now()
  WHERE id = p_shop_id;

  PERFORM set_config('app.owner_shop_status_rpc', 'false', true);

  INSERT INTO public.audit_logs(actor_id, action, entity, entity_id, old_data, new_data)
  VALUES (
    auth.uid(),
    'update'::public.audit_action,
    'shop',
    p_shop_id,
    jsonb_build_object('status', v_old.status, 'is_active', v_old.is_active),
    jsonb_build_object('status', p_status, 'is_active', v_active)
  );

  RETURN jsonb_build_object(
    'shop_id', p_shop_id,
    'status', p_status,
    'is_active', v_active,
    'updated_at', now()
  );
END;
$function$

