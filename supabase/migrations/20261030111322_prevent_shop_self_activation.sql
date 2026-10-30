
CREATE OR REPLACE FUNCTION public.guard_shop_activation_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Shop owners may submit a shop profile, but cannot activate or subscribe it themselves.
    NEW.is_active := false;
    NEW.status := 'inactive';
    NEW.subscription_plan_id := NULL;
    NEW.subscription_expires_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.is_active IS DISTINCT FROM NEW.is_active
     OR OLD.status IS DISTINCT FROM NEW.status
     OR OLD.subscription_plan_id IS DISTINCT FROM NEW.subscription_plan_id
     OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at THEN
    RAISE EXCEPTION 'Only an active super_admin or trusted payment process can change shop activation and subscription fields'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_shop_activation_fields() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_guard_shop_activation_fields ON public.shops;
CREATE TRIGGER trg_guard_shop_activation_fields
BEFORE INSERT OR UPDATE ON public.shops
FOR EACH ROW EXECUTE FUNCTION public.guard_shop_activation_fields();
