
create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
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
     and not public.is_shop_owner(v_order.shop_id)
     and not public.is_super_admin() then
    raise exception 'Forbidden' using errcode = '42501';
  end if;

  -- Until a verified refund workflow exists, cancellation is limited to unpaid pending orders.
  if v_order.status <> 'pending'::public.order_status then
    raise exception 'Only pending unpaid orders can be cancelled; contact support for paid or processing orders'
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

  return true;
end;
$$;

revoke all on function public.cancel_order(uuid,text) from public, anon;
grant execute on function public.cancel_order(uuid,text) to authenticated;
