-- Source-controlled reconciliation for the already-applied customer credit ledger
-- and grocery database hardening. This migration is intentionally idempotent.
CREATE TABLE IF NOT EXISTS public.shop_credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  customer_name text NOT NULL CHECK (length(trim(customer_name)) BETWEEN 1 AND 120),
  customer_phone text CHECK (customer_phone IS NULL OR length(customer_phone) <= 30),
  entry_type text NOT NULL CHECK (entry_type IN ('credit_sale','payment_received','adjustment')),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  notes text CHECK (notes IS NULL OR length(notes) <= 500),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS shop_credit_ledger_shop_date_idx
  ON public.shop_credit_ledger(shop_id, entry_date DESC, created_at DESC);
ALTER TABLE public.shop_credit_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shop_credit_ledger_owner_all ON public.shop_credit_ledger;
CREATE POLICY shop_credit_ledger_owner_all ON public.shop_credit_ledger
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = shop_credit_ledger.shop_id
      AND s.owner_id = (SELECT auth.uid())
  ))
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = shop_credit_ledger.shop_id
        AND s.owner_id = (SELECT auth.uid())
    )
    AND created_by = (SELECT auth.uid())
  );
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shop_credit_ledger TO authenticated;

-- Index purchase foreign keys used by joins and referential checks.
CREATE INDEX IF NOT EXISTS grocery_purchases_product_id_idx
  ON public.grocery_stock_purchases(product_id);
CREATE INDEX IF NOT EXISTS grocery_purchases_supplier_id_idx
  ON public.grocery_stock_purchases(supplier_id);

-- A purchase must be recorded through the validated atomic RPC, not anonymous access.
REVOKE EXECUTE ON FUNCTION public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_approve_shop_application(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_approve_shop_application(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_set_shop_status(uuid, public.shop_status) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_set_shop_status(uuid, public.shop_status) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_set_shopkeeper_status(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_set_shopkeeper_status(uuid, boolean) TO authenticated;

-- Keep expense write policies owner-scoped and evaluate auth.uid() once per statement.
DROP POLICY IF EXISTS grocery_expenses_insert ON public.grocery_expenses;
CREATE POLICY grocery_expenses_insert ON public.grocery_expenses
  FOR INSERT TO authenticated
  WITH CHECK (
    private.is_shop_owner(shop_id)
    AND created_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = grocery_expenses.shop_id
        AND s.business_type = 'grocery'
        AND s.is_active = true
        AND s.status = 'active'
        AND s.subscription_expires_at > now()
    )
  );
DROP POLICY IF EXISTS grocery_expenses_update ON public.grocery_expenses;
CREATE POLICY grocery_expenses_update ON public.grocery_expenses
  FOR UPDATE TO authenticated
  USING (
    private.is_shop_owner(shop_id)
    AND EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = grocery_expenses.shop_id
        AND s.business_type = 'grocery'
        AND s.is_active = true
        AND s.status = 'active'
        AND s.subscription_expires_at > now()
    )
  )
  WITH CHECK (
    private.is_shop_owner(shop_id)
    AND created_by = (SELECT auth.uid())
  );


-- Grocery order stock deduction and COD cancellation restoration are recorded in stock movement history.
CREATE OR REPLACE FUNCTION private.place_order(p_shop_id uuid, p_address_id uuid, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_cust uuid := auth.uid();
  v_order_id uuid;
  v_subtotal numeric := 0;
  v_shipping numeric;
  v_total numeric;
  v_addr jsonb;
  v_item jsonb;
  v_prod record;
  v_qty integer;
  v_price numeric;
  v_ids uuid[];
  v_shop_is_active boolean;
  v_shop_status public.shop_status;
  v_shop_expires timestamptz;
  v_shop_orders_month integer;
  v_shop_last_reset timestamptz;
  v_plan_max_orders integer;
BEGIN
  IF v_cust IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = v_cust AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Active account required to place an order' USING ERRCODE = '42501';
  END IF;
  IF p_shop_id IS NULL THEN
    RAISE EXCEPTION 'Shop is required' USING ERRCODE = '22023';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Empty cart' USING ERRCODE = '22023';
  END IF;

  -- Lock the shop row so simultaneous orders cannot bypass the monthly cap
  -- or race the monthly counter reset/increment.
  SELECT s.is_active, s.status, s.subscription_expires_at,
         s.total_orders_this_month, s.last_order_reset,
         sp.max_orders_per_month
  INTO v_shop_is_active, v_shop_status, v_shop_expires,
       v_shop_orders_month, v_shop_last_reset, v_plan_max_orders
  FROM public.shops s
  LEFT JOIN public.subscription_plans sp ON sp.id = s.subscription_plan_id
  WHERE s.id = p_shop_id
  FOR UPDATE OF s;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shop not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_shop_is_active IS DISTINCT FROM true
     OR v_shop_status <> 'active'::public.shop_status THEN
    RAISE EXCEPTION 'Shop inactive' USING ERRCODE = '55000';
  END IF;
  IF v_shop_expires IS NULL OR v_shop_expires <= now() THEN
    RAISE EXCEPTION 'Shop subscription expired or invalid' USING ERRCODE = '55000';
  END IF;

  IF date_trunc('month', v_shop_last_reset) < date_trunc('month', now()) THEN
    UPDATE public.shops
    SET total_orders_this_month = 0, last_order_reset = now()
    WHERE id = p_shop_id;
    v_shop_orders_month := 0;
  END IF;

  IF v_plan_max_orders IS NOT NULL
     AND v_shop_orders_month >= v_plan_max_orders THEN
    RAISE EXCEPTION 'Monthly order limit reached: %', v_plan_max_orders
      USING ERRCODE = '55000';
  END IF;

  SELECT to_jsonb(a) INTO v_addr
  FROM public.delivery_addresses a
  WHERE a.id = p_address_id AND a.user_id = v_cust;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid address' USING ERRCODE = '42501';
  END IF;

  BEGIN
    SELECT array_agg((elem->>'product_id')::uuid)
    INTO v_ids
    FROM jsonb_array_elements(p_items) elem;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid product_id' USING ERRCODE = '22023';
  END;

  IF array_length(v_ids, 1) IS DISTINCT FROM
     (SELECT count(DISTINCT x)::integer FROM unnest(v_ids) x) THEN
    RAISE EXCEPTION 'Duplicate or invalid product IDs' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE((value::text)::numeric, 40)
  INTO v_shipping
  FROM public.platform_settings
  WHERE key = 'shipping_fee_default';
  v_shipping := COALESCE(v_shipping, 40);
  IF v_shipping < 0 THEN
    RAISE EXCEPTION 'Invalid shipping fee configuration' USING ERRCODE = '55000';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF NOT (v_item ? 'product_id' AND v_item ? 'quantity') THEN
      RAISE EXCEPTION 'Each item must have product_id and quantity';
    END IF;

    BEGIN
      v_qty := (v_item->>'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Quantity must be integer' USING ERRCODE = '22023';
    END;
    IF v_qty <= 0 OR v_qty > 100 THEN
      RAISE EXCEPTION 'Quantity 1-100 only' USING ERRCODE = '22023';
    END IF;

    SELECT id, shop_id, COALESCE(sale_price, price) AS eff_price,
           stock, is_available
    INTO v_prod
    FROM public.products
    WHERE id = (v_item->>'product_id')::uuid
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_prod.shop_id <> p_shop_id THEN
      RAISE EXCEPTION 'Product from different shop' USING ERRCODE = '22023';
    END IF;
    IF NOT v_prod.is_available THEN
      RAISE EXCEPTION 'Product unavailable' USING ERRCODE = '55000';
    END IF;
    IF v_prod.stock < v_qty THEN
      RAISE EXCEPTION 'Insufficient stock for %: have %, need %',
        v_prod.id, v_prod.stock, v_qty USING ERRCODE = '55000';
    END IF;

    v_subtotal := v_subtotal + (v_prod.eff_price * v_qty);
  END LOOP;

  v_total := v_subtotal + v_shipping;

  INSERT INTO public.orders (
    customer_id, shop_id, subtotal, shipping_fee, total, shipping_address, status
  )
  VALUES (v_cust, p_shop_id, v_subtotal, v_shipping, v_total, v_addr, 'pending')
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT COALESCE(sale_price, price)
    INTO v_price
    FROM public.products
    WHERE id = (v_item->>'product_id')::uuid;

    v_qty := (v_item->>'quantity')::integer;

    INSERT INTO public.order_items (
      order_id, product_id, quantity, price_at_purchase, total_price
    )
    VALUES (
      v_order_id, (v_item->>'product_id')::uuid, v_qty, v_price, v_price * v_qty
    );

    UPDATE public.products
    SET stock = stock - v_qty
    WHERE id = (v_item->>'product_id')::uuid;

    IF EXISTS (SELECT 1 FROM public.shops WHERE id = p_shop_id AND business_type = 'grocery') THEN
      INSERT INTO public.grocery_stock_movements
        (shop_id, product_id, movement_type, quantity_change, stock_before, stock_after, reference_id, notes, created_by)
      SELECT p_shop_id, p.id, 'sale', -v_qty, p.stock + v_qty, p.stock,
             v_order_id, 'Customer order stock deduction', v_cust
      FROM public.products p WHERE p.id = (v_item->>'product_id')::uuid;
    END IF;
  END LOOP;

  UPDATE public.shops
  SET total_orders_this_month = v_shop_orders_month + 1
  WHERE id = p_shop_id;

  INSERT INTO public.order_status_history (
    order_id, old_status, new_status, changed_by
  )
  VALUES (v_order_id, NULL, 'pending', v_cust);

  RETURN v_order_id;
END;
$function$


CREATE OR REPLACE FUNCTION private.cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_order public.orders%rowtype;
  v_item record;
  v_stock_after integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Active account required to cancel an order' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_order.customer_id IS DISTINCT FROM auth.uid()
     AND NOT private.is_shop_owner(v_order.shop_id)
     AND NOT private.is_super_admin() THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF v_order.status <> 'pending'::public.order_status
     OR v_order.payment_status <> 'unpaid'
     OR v_order.payment_method <> 'cash_on_delivery' THEN
    RAISE EXCEPTION 'Only pending, unpaid cash-on-delivery orders can be cancelled; contact support for other orders'
      USING ERRCODE = '55000';
  END IF;

  -- Match place_order's lock order (shop first, then products) to avoid
  -- deadlocks between concurrent stock deduction and cancellation restoration.
  PERFORM 1
  FROM public.shops
  WHERE id = v_order.shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shop not found' USING ERRCODE = 'P0002';
  END IF;

  FOR v_item IN
    SELECT product_id, quantity
    FROM public.order_items
    WHERE order_id = p_order_id
  LOOP
    UPDATE public.products
    SET stock = stock + v_item.quantity
    WHERE id = v_item.product_id
    RETURNING stock INTO v_stock_after;

    IF EXISTS (SELECT 1 FROM public.shops WHERE id = v_order.shop_id AND business_type = 'grocery') THEN
      INSERT INTO public.grocery_stock_movements
        (shop_id, product_id, movement_type, quantity_change, stock_before, stock_after, reference_id, notes, created_by)
      VALUES
        (v_order.shop_id, v_item.product_id, 'order_cancelled', v_item.quantity,
         v_stock_after - v_item.quantity, v_stock_after, p_order_id,
         'Cancelled COD order stock restored', auth.uid());
    END IF;
  END LOOP;

  PERFORM set_config(
    'app.order_status_reason',
    coalesce(nullif(left(coalesce(p_reason, ''), 500), ''), ''),
    true
  );

  UPDATE public.orders
  SET status = 'cancelled'::public.order_status
  WHERE id = p_order_id;

  PERFORM set_config('app.order_status_reason', '', true);

  RETURN true;
END;
$function$

