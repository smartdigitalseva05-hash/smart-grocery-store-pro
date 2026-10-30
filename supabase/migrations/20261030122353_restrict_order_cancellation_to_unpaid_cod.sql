create or replace function private.cancel_order(p_order_id uuid, p_reason text default null)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_order public.orders%rowtype;
  v_item record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  if v_order.customer_id is distinct from auth.uid()
     and not private.is_shop_owner(v_order.shop_id)
     and not private.is_super_admin() then
    raise exception 'Forbidden' using errcode = '42501';
  end if;

  -- Cancellation is allowed only before processing and before any payment is collected.
  if v_order.status <> 'pending'::public.order_status
     or v_order.payment_status <> 'unpaid'
     or v_order.payment_method <> 'cash_on_delivery' then
    raise exception 'Only pending, unpaid cash-on-delivery orders can be cancelled; contact support for other orders'
      using errcode = '55000';
  end if;

  for v_item in
    select product_id, quantity
    from public.order_items
    where order_id = p_order_id
  loop
    update public.products
    set stock = stock + v_item.quantity
    where id = v_item.product_id;
  end loop;

  update public.orders
  set status = 'cancelled'::public.order_status
  where id = p_order_id;

  insert into public.order_status_history(order_id, old_status, new_status, changed_by, reason)
  values (p_order_id, v_order.status, 'cancelled'::public.order_status, auth.uid(), nullif(left(coalesce(p_reason, ''), 500), ''));

  return true;
end;
$function$;