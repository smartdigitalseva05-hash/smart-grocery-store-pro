-- Allow Daily Needs shops to use the existing supplier, stock-purchase and expense
-- ledger while preserving active-subscription, shop-owner and creator checks.
ALTER POLICY grocery_suppliers_insert ON public.grocery_suppliers
WITH CHECK (
  private.is_shop_owner(shop_id)
  AND EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = grocery_suppliers.shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
);

ALTER POLICY grocery_supplier_payments_insert ON public.grocery_supplier_payments
WITH CHECK (
  created_by = (SELECT auth.uid())
  AND private.is_shop_owner(shop_id)
  AND EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = grocery_supplier_payments.shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
);

ALTER POLICY grocery_expenses_insert ON public.grocery_expenses
WITH CHECK (
  private.is_shop_owner(shop_id)
  AND created_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = grocery_expenses.shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
);

ALTER POLICY grocery_expenses_update ON public.grocery_expenses
USING (
  private.is_shop_owner(shop_id)
  AND EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = grocery_expenses.shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
)
WITH CHECK (
  private.is_shop_owner(shop_id)
  AND (
    created_by = (SELECT auth.uid())
    OR private.is_super_admin()
  )
  AND EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = grocery_expenses.shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
);

CREATE OR REPLACE FUNCTION private.grocery_record_purchase(
  p_shop_id uuid,
  p_product_id uuid,
  p_supplier_id uuid,
  p_quantity integer,
  p_unit_cost numeric,
  p_invoice_number text DEFAULT NULL,
  p_purchase_date date DEFAULT CURRENT_DATE,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_purchase_id uuid;
  v_before integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sign in required';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 OR p_quantity > 1000000 THEN
    RAISE EXCEPTION 'Enter a valid purchase quantity';
  END IF;
  IF p_unit_cost IS NULL OR p_unit_cost < 0 OR p_unit_cost > 100000000 THEN
    RAISE EXCEPTION 'Enter a valid unit cost';
  END IF;
  IF NOT private.is_shop_owner(p_shop_id) THEN
    RAISE EXCEPTION 'You do not have access to this shop';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = p_shop_id
      AND s.business_type IN ('grocery','daily_needs')
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  ) THEN
    RAISE EXCEPTION 'Active Grocery or Daily Needs shop subscription required';
  END IF;
  IF p_supplier_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.grocery_suppliers x
    WHERE x.id = p_supplier_id
      AND x.shop_id = p_shop_id
      AND x.is_active = true
  ) THEN
    RAISE EXCEPTION 'Choose a valid supplier for this shop';
  END IF;
  SELECT stock INTO v_before
  FROM public.products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product does not belong to this shop';
  END IF;
  IF v_before + p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'Stock quantity limit exceeded';
  END IF;
  INSERT INTO public.grocery_stock_purchases(
    shop_id,product_id,supplier_id,quantity,unit_cost,invoice_number,
    purchase_date,notes,created_by
  )
  VALUES (
    p_shop_id,p_product_id,p_supplier_id,p_quantity,p_unit_cost,
    NULLIF(trim(p_invoice_number),''),COALESCE(p_purchase_date,current_date),
    NULLIF(trim(p_notes),''),auth.uid()
  )
  RETURNING id INTO v_purchase_id;
  UPDATE public.products
  SET stock = v_before + p_quantity, is_available = true, updated_at = now()
  WHERE id = p_product_id AND shop_id = p_shop_id;
  INSERT INTO public.grocery_stock_movements(
    shop_id,product_id,movement_type,quantity_change,stock_before,stock_after,
    reference_id,notes,created_by
  )
  VALUES (
    p_shop_id,p_product_id,'purchase',p_quantity,v_before,v_before+p_quantity,
    v_purchase_id,'Stock received from purchase',auth.uid()
  );
  RETURN v_purchase_id;
END;
$function$;
