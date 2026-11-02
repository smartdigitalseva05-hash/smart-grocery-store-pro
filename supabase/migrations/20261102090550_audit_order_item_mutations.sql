-- Add privacy-minimized audit coverage for order line-item mutations.
-- Never copy product names, customer data, or free-form content into audit payloads.
CREATE OR REPLACE FUNCTION private.audit_order_item_mutations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_source jsonb;
  v_action public.audit_action;
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN
    v_old := pg_catalog.to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN
    v_new := pg_catalog.to_jsonb(NEW);
  END IF;

  v_source := coalesce(v_new,v_old);
  v_action := CASE TG_OP
    WHEN 'INSERT' THEN 'create'::public.audit_action
    WHEN 'UPDATE' THEN 'update'::public.audit_action
    ELSE 'delete'::public.audit_action
  END;

  IF TG_OP = 'UPDATE'
     AND OLD.order_id IS NOT DISTINCT FROM NEW.order_id
     AND OLD.product_id IS NOT DISTINCT FROM NEW.product_id
     AND OLD.quantity IS NOT DISTINCT FROM NEW.quantity
     AND OLD.price_at_purchase IS NOT DISTINCT FROM NEW.price_at_purchase
     AND OLD.total_price IS NOT DISTINCT FROM NEW.total_price THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.audit_logs(actor_id,action,entity,entity_id,old_data,new_data)
  VALUES (
    auth.uid(),
    v_action,
    'order_items',
    nullif(v_source->>'id','')::uuid,
    CASE WHEN v_old IS NULL THEN '{}'::jsonb ELSE
      pg_catalog.jsonb_build_object(
        'order_id',v_old->'order_id',
        'product_id',v_old->'product_id',
        'quantity',v_old->'quantity',
        'price_at_purchase',v_old->'price_at_purchase',
        'total_price',v_old->'total_price'
      ) END,
    CASE WHEN v_new IS NULL THEN '{}'::jsonb ELSE
      pg_catalog.jsonb_build_object(
        'order_id',v_new->'order_id',
        'product_id',v_new->'product_id',
        'quantity',v_new->'quantity',
        'price_at_purchase',v_new->'price_at_purchase',
        'total_price',v_new->'total_price'
      ) END
  );

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.audit_order_item_mutations()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS audit_order_item_mutations ON public.order_items;
CREATE TRIGGER audit_order_item_mutations
AFTER INSERT OR UPDATE OR DELETE ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION private.audit_order_item_mutations();
