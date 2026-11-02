-- Preserve append-only integrity for supplier payments, stock purchases and
-- stock movements, and write compact audit events for all grocery financial
-- ledger mutations. Expense rows remain editable, but every change is audited.
CREATE OR REPLACE FUNCTION private.prevent_grocery_ledger_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'Grocery financial ledger rows are append-only'
    USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION private.prevent_grocery_ledger_mutation()
  FROM PUBLIC,anon,authenticated,service_role;

DROP TRIGGER IF EXISTS trg_prevent_supplier_payment_mutation ON public.grocery_supplier_payments;
CREATE TRIGGER trg_prevent_supplier_payment_mutation
  BEFORE UPDATE OR DELETE ON public.grocery_supplier_payments
  FOR EACH ROW EXECUTE FUNCTION private.prevent_grocery_ledger_mutation();

DROP TRIGGER IF EXISTS trg_prevent_stock_purchase_mutation ON public.grocery_stock_purchases;
CREATE TRIGGER trg_prevent_stock_purchase_mutation
  BEFORE UPDATE OR DELETE ON public.grocery_stock_purchases
  FOR EACH ROW EXECUTE FUNCTION private.prevent_grocery_ledger_mutation();

DROP TRIGGER IF EXISTS trg_prevent_stock_movement_mutation ON public.grocery_stock_movements;
CREATE TRIGGER trg_prevent_stock_movement_mutation
  BEFORE UPDATE OR DELETE ON public.grocery_stock_movements
  FOR EACH ROW EXECUTE FUNCTION private.prevent_grocery_ledger_mutation();

CREATE OR REPLACE FUNCTION private.audit_grocery_financial_ledger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_source jsonb;
  v_old_data jsonb;
  v_new_data jsonb;
  v_actor uuid;
  v_entity_id uuid;
  v_action public.audit_action;
BEGIN
  IF TG_OP IN ('UPDATE','DELETE') THEN v_old := pg_catalog.to_jsonb(OLD); END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN v_new := pg_catalog.to_jsonb(NEW); END IF;
  v_source := coalesce(v_new,v_old);
  v_entity_id := (v_source->>'id')::uuid;
  v_actor := coalesce(auth.uid(),nullif(v_source->>'created_by','')::uuid);

  IF v_old IS NOT NULL THEN
    v_old_data := pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
      'shop_id',v_old->'shop_id',
      'supplier_id',v_old->'supplier_id',
      'product_id',v_old->'product_id',
      'amount',v_old->'amount',
      'payment_date',v_old->'payment_date',
      'payment_method',v_old->'payment_method',
      'quantity',v_old->'quantity',
      'unit_cost',v_old->'unit_cost',
      'total_cost',v_old->'total_cost',
      'purchase_date',v_old->'purchase_date',
      'movement_type',v_old->'movement_type',
      'quantity_change',v_old->'quantity_change',
      'stock_before',v_old->'stock_before',
      'stock_after',v_old->'stock_after',
      'reference_id',v_old->'reference_id',
      'expense_category',v_old->'expense_category',
      'expense_date',v_old->'expense_date'
    ));
  END IF;

  IF v_new IS NOT NULL THEN
    v_new_data := pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
      'shop_id',v_new->'shop_id',
      'supplier_id',v_new->'supplier_id',
      'product_id',v_new->'product_id',
      'amount',v_new->'amount',
      'payment_date',v_new->'payment_date',
      'payment_method',v_new->'payment_method',
      'quantity',v_new->'quantity',
      'unit_cost',v_new->'unit_cost',
      'total_cost',v_new->'total_cost',
      'purchase_date',v_new->'purchase_date',
      'movement_type',v_new->'movement_type',
      'quantity_change',v_new->'quantity_change',
      'stock_before',v_new->'stock_before',
      'stock_after',v_new->'stock_after',
      'reference_id',v_new->'reference_id',
      'expense_category',v_new->'expense_category',
      'expense_date',v_new->'expense_date'
    ));
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

REVOKE ALL ON FUNCTION private.audit_grocery_financial_ledger()
  FROM PUBLIC,anon,authenticated,service_role;

DROP TRIGGER IF EXISTS trg_audit_grocery_supplier_payments ON public.grocery_supplier_payments;
CREATE TRIGGER trg_audit_grocery_supplier_payments
  AFTER INSERT ON public.grocery_supplier_payments
  FOR EACH ROW EXECUTE FUNCTION private.audit_grocery_financial_ledger();

DROP TRIGGER IF EXISTS trg_audit_grocery_stock_purchases ON public.grocery_stock_purchases;
CREATE TRIGGER trg_audit_grocery_stock_purchases
  AFTER INSERT ON public.grocery_stock_purchases
  FOR EACH ROW EXECUTE FUNCTION private.audit_grocery_financial_ledger();

DROP TRIGGER IF EXISTS trg_audit_grocery_stock_movements ON public.grocery_stock_movements;
CREATE TRIGGER trg_audit_grocery_stock_movements
  AFTER INSERT ON public.grocery_stock_movements
  FOR EACH ROW EXECUTE FUNCTION private.audit_grocery_financial_ledger();

DROP TRIGGER IF EXISTS trg_audit_grocery_expenses ON public.grocery_expenses;
CREATE TRIGGER trg_audit_grocery_expenses
  AFTER INSERT OR UPDATE OR DELETE ON public.grocery_expenses
  FOR EACH ROW EXECUTE FUNCTION private.audit_grocery_financial_ledger();
