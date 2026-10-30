CREATE OR REPLACE FUNCTION public.audit_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_reason text;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT public.validate_status_transition(OLD.status, NEW.status) THEN
      RAISE EXCEPTION 'Invalid transition % -> %', OLD.status, NEW.status;
    END IF;

    v_reason := nullif(
      left(coalesce(current_setting('app.order_status_reason', true), ''), 500),
      ''
    );

    INSERT INTO public.audit_logs (
      actor_id, action, entity, entity_id, old_data, new_data
    )
    VALUES (
      auth.uid(), 'order_status', 'orders', NEW.id,
      jsonb_build_object('old', OLD.status),
      jsonb_build_object('new', NEW.status, 'reason', v_reason)
    );

    INSERT INTO public.order_status_history (
      order_id, old_status, new_status, changed_by, reason
    )
    VALUES (
      NEW.id, OLD.status, NEW.status, auth.uid(), v_reason
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.cancel_order(
  p_order_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_order public.orders%rowtype;
  v_item record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
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

  FOR v_item IN
    SELECT product_id, quantity
    FROM public.order_items
    WHERE order_id = p_order_id
  LOOP
    UPDATE public.products
    SET stock = stock + v_item.quantity
    WHERE id = v_item.product_id;
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
$function$;