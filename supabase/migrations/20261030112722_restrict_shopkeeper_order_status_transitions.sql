
create or replace function public.update_order_status_by_shopkeeper(
  p_order_id uuid,
  p_new_status public.order_status
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_new_status not in (
    'processing'::public.order_status,
    'out_for_delivery'::public.order_status,
    'delivered'::public.order_status
  ) then
    raise exception 'Shopkeeper may only move orders to processing, out for delivery, or delivered'
      using errcode = '22023';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  if not public.is_shop_owner(v_order.shop_id) and not public.is_super_admin() then
    raise exception 'Only the owning shopkeeper or active Super Admin can update this order'
      using errcode = '42501';
  end if;

  if not public.validate_status_transition(v_order.status, p_new_status) then
    raise exception 'Invalid order status transition: % -> %', v_order.status, p_new_status
      using errcode = '55000';
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id;

  return true;
end;
$$;

revoke all on function public.update_order_status_by_shopkeeper(uuid,public.order_status) from public, anon;
grant execute on function public.update_order_status_by_shopkeeper(uuid,public.order_status) to authenticated;
