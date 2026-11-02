-- Audit security-sensitive identity, shop activation, and trial mutations.
-- Capture only explicitly approved security fields; never copy contact details.
CREATE OR REPLACE FUNCTION private.audit_security_sensitive_mutations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_source jsonb;
  v_old_data jsonb := '{}'::jsonb;
  v_new_data jsonb := '{}'::jsonb;
  v_allowed_fields text[];
  v_field text;
  v_entity_id uuid;
  v_actor uuid;
  v_action public.audit_action;
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN
    v_old := pg_catalog.to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN
    v_new := pg_catalog.to_jsonb(NEW);
  END IF;
  v_source := coalesce(v_new,v_old);
  v_entity_id := nullif(v_source->>'id','')::uuid;
  v_actor := auth.uid();

  v_allowed_fields := CASE TG_TABLE_NAME
    WHEN 'profiles' THEN ARRAY['role','is_active']
    WHEN 'shops' THEN ARRAY[
      'owner_id','business_type','status','is_active',
      'subscription_plan_id','subscription_expires_at'
    ]
    WHEN 'shop_trials' THEN ARRAY[
      'owner_id','shop_id','status','started_at','ends_at'
    ]
    ELSE ARRAY[]::text[]
  END;

  IF v_old IS NOT NULL THEN
    FOREACH v_field IN ARRAY v_allowed_fields LOOP
      IF v_old ? v_field THEN
        v_old_data := v_old_data || pg_catalog.jsonb_build_object(v_field,v_old->v_field);
      END IF;
    END LOOP;
  END IF;
  IF v_new IS NOT NULL THEN
    FOREACH v_field IN ARRAY v_allowed_fields LOOP
      IF v_new ? v_field THEN
        v_new_data := v_new_data || pg_catalog.jsonb_build_object(v_field,v_new->v_field);
      END IF;
    END LOOP;
  END IF;

  v_action := CASE TG_OP
    WHEN 'INSERT' THEN 'create'::public.audit_action
    WHEN 'UPDATE' THEN 'update'::public.audit_action
    ELSE 'delete'::public.audit_action
  END;

  INSERT INTO public.audit_logs(actor_id,action,entity,entity_id,old_data,new_data)
  VALUES(v_actor,v_action,TG_TABLE_NAME,v_entity_id,v_old_data,v_new_data);

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION private.audit_security_sensitive_mutations()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS audit_profile_security_changes ON public.profiles;
CREATE TRIGGER audit_profile_security_changes
AFTER INSERT OR UPDATE OR DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION private.audit_security_sensitive_mutations();

DROP TRIGGER IF EXISTS audit_shop_security_changes ON public.shops;
CREATE TRIGGER audit_shop_security_changes
AFTER INSERT OR UPDATE OR DELETE ON public.shops
FOR EACH ROW EXECUTE FUNCTION private.audit_security_sensitive_mutations();

DROP TRIGGER IF EXISTS audit_shop_trial_security_changes ON public.shop_trials;
CREATE TRIGGER audit_shop_trial_security_changes
AFTER INSERT OR UPDATE OR DELETE ON public.shop_trials
FOR EACH ROW EXECUTE FUNCTION private.audit_security_sensitive_mutations();
