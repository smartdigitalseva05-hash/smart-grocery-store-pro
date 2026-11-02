-- Extend the private audit trigger to the remaining high-value catalogue,
-- inventory, reservation, staff and platform-setting mutation paths.
-- Sensitive values (addresses, phone numbers, names, IMEI/serials, free text,
-- notes, documents, secrets and payment references) are never copied.

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
  IF TG_OP IN ('UPDATE','DELETE') THEN v_old := pg_catalog.to_jsonb(OLD); END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN v_new := pg_catalog.to_jsonb(NEW); END IF;
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
    WHEN 'categories' THEN ARRAY['name','business_type','is_active']
    WHEN 'subcategories' THEN ARRAY['category_id','name','is_active']
    WHEN 'products' THEN ARRAY[
      'shop_id','category_id','subcategory_id','name','price','sale_price',
      'stock','is_available'
    ]
    WHEN 'digital_service_applications' THEN ARRAY[
      'shop_id','application_number','service_name','applied_on','expected_date',
      'application_status','service_fee','amount_paid','customer_id'
    ]
    WHEN 'electronics_inventory' THEN ARRAY[
      'shop_id','product_id','device_name','brand','model','purchase_date',
      'warranty_start','warranty_end','purchase_price','sale_price',
      'device_status','sold_at'
    ]
    WHEN 'garment_product_variants' THEN ARRAY[
      'shop_id','product_id','size_label','color_name','price','stock','is_available'
    ]
    WHEN 'jewellery_product_details' THEN ARRAY[
      'shop_id','product_id','metal_type','purity','gross_weight_g','net_weight_g',
      'stone_weight_ct','making_charge','making_charge_type','metal_rate_per_gram',
      'rate_recorded_at'
    ]
    WHEN 'medical_inventory_batches' THEN ARRAY[
      'shop_id','product_id','medicine_name','batch_number','manufactured_on',
      'expiry_date','quantity','prescription_required','batch_status'
    ]
    WHEN 'hotel_rooms' THEN ARRAY[
      'shop_id','room_type','floor_label','capacity','base_rate','room_status','is_active'
    ]
    WHEN 'hotel_reservations' THEN ARRAY[
      'shop_id','room_id','booking_number','guest_count','check_in','check_out',
      'status','nightly_rate'
    ]
    WHEN 'office_employees' THEN ARRAY[
      'shop_id','employee_code','designation','employment_type','joined_on','is_active'
    ]
    WHEN 'office_attendance' THEN ARRAY[
      'shop_id','employee_id','work_date','attendance_status','check_in','check_out'
    ]
    WHEN 'grocery_suppliers' THEN ARRAY['shop_id','is_active']
    WHEN 'delivery_addresses' THEN ARRAY['user_id','is_default']
    WHEN 'platform_settings' THEN ARRAY['key','is_public']
    WHEN 'subscription_plans' THEN ARRAY[
      'name','price_monthly','price_yearly','max_products','max_orders_per_month','is_active'
    ]
    WHEN 'shop_subscriptions' THEN ARRAY[
      'shop_id','plan_id','status','starts_at','ends_at','billing_cycle'
    ]
    WHEN 'restaurant_tables' THEN ARRAY[
      'shop_id','table_code','capacity','table_status','is_enabled'
    ]
    WHEN 'restaurant_menu_items' THEN ARRAY[
      'shop_id','name','category','price','prep_time_minutes','is_available','sort_order'
    ]
    WHEN 'restaurant_kitchen_tickets' THEN ARRAY[
      'shop_id','ticket_number','table_id','guest_count','status','source_order_id'
    ]
    WHEN 'restaurant_kitchen_ticket_items' THEN ARRAY[
      'ticket_id','menu_item_id','quantity','unit_price'
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

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.audit_business_module_mutations()
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'categories',
    'subcategories',
    'products',
    'digital_service_applications',
    'electronics_inventory',
    'garment_product_variants',
    'jewellery_product_details',
    'medical_inventory_batches',
    'hotel_rooms',
    'hotel_reservations',
    'office_employees',
    'office_attendance',
    'grocery_suppliers',
    'delivery_addresses',
    'platform_settings',
    'subscription_plans',
    'shop_subscriptions',
    'restaurant_tables',
    'restaurant_menu_items',
    'restaurant_kitchen_tickets',
    'restaurant_kitchen_ticket_items'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS audit_business_module_mutations ON public.%I',v_table);
    EXECUTE format(
      'CREATE TRIGGER audit_business_module_mutations AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.audit_business_module_mutations()',
      v_table
    );
  END LOOP;
END;
$migration$;
