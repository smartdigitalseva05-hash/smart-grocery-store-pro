-- Capture sensitive operational record changes without copying customer PII,
-- free-form notes, payroll amounts or payment references into the audit trail.
CREATE OR REPLACE FUNCTION private.audit_business_module_mutations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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
  v_actor := coalesce(
    auth.uid(),
    nullif(v_source->>'created_by','')::uuid,
    nullif(v_source->>'customer_id','')::uuid
  );

  v_allowed_fields := CASE TG_TABLE_NAME
    WHEN 'electronics_service_jobs' THEN ARRAY[
      'shop_id','inventory_id','status','estimated_cost','approved_cost',
      'final_cost','due_at','delivered_at'
    ]
    WHEN 'hotel_booking_requests' THEN ARRAY[
      'shop_id','requested_room_type','check_in','check_out','status','reservation_id'
    ]
    WHEN 'hotel_housekeeping_tasks' THEN ARRAY[
      'shop_id','room_id','task_type','due_at','status','completed_at'
    ]
    WHEN 'office_leave_requests' THEN ARRAY[
      'shop_id','employee_id','leave_type','start_date','end_date','days_count',
      'status','reviewed_at'
    ]
    WHEN 'office_payroll_records' THEN ARRAY[
      'shop_id','employee_id','period_start','period_end','status',
      'payment_method','paid_at'
    ]
    WHEN 'office_tasks' THEN ARRAY[
      'shop_id','employee_id','priority','due_at','status','completed_at'
    ]
    WHEN 'restaurant_reservations' THEN ARRAY[
      'shop_id','table_id','party_size','reservation_at','duration_minutes','status'
    ]
    ELSE ARRAY['shop_id']
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

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.audit_business_module_mutations()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.electronics_service_jobs;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.electronics_service_jobs
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.hotel_booking_requests;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.hotel_booking_requests
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.hotel_housekeeping_tasks;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.hotel_housekeeping_tasks
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.office_leave_requests;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.office_leave_requests
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.office_payroll_records;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.office_payroll_records
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.office_tasks;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.office_tasks
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();

DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.restaurant_reservations;
CREATE TRIGGER audit_business_module_mutations
  AFTER INSERT OR UPDATE OR DELETE ON public.restaurant_reservations
  FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations();
