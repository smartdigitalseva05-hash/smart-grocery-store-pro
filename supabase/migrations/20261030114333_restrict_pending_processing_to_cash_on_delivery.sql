
create or replace function private.update_order_status_by_shopkeeper(
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
  v_cod_start boolean;
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

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'Order not found' using errcode = 'P0002'; end if;

  if not private.is_shop_owner(v_order.shop_id) and not private.is_super_admin() then
    raise exception 'Only the owning shopkeeper or active Super Admin can update this order'
      using errcode = '42501';
  end if;

  v_cod_start :=
    v_order.status = 'pending'::public.order_status
    and p_new_status = 'processing'::public.order_status
    and v_order.payment_method = 'cash_on_delivery'
    and v_order.payment_status = 'unpaid';

  if v_order.status = 'pending'::public.order_status
     and p_new_status = 'processing'::public.order_status
     and not v_cod_start then
    raise exception 'Pending orders can only be processed as unpaid cash-on-delivery orders'
      using errcode = '55000';
  end if;

  if not public.validate_status_transition(v_order.status, p_new_status) then
    raise exception 'Invalid order status transition: % -> %', v_order.status, p_new_status
      using errcode = '55000';
  end if;

  if p_new_status = 'delivered'
     and v_order.payment_method = 'cash_on_delivery'
     and v_order.payment_status = 'unpaid' then
    update public.orders set status = p_new_status, payment_status = 'paid' where id = p_order_id;
    insert into public.audit_logs(actor_id, action, entity, entity_id, old_data, new_data)
    values (
      auth.uid(), 'payment'::public.audit_action, 'order', p_order_id,
      jsonb_build_object('payment_method', 'cash_on_delivery', 'payment_status', 'unpaid'),
      jsonb_build_object('payment_method', 'cash_on_delivery', 'payment_status', 'paid', 'collected_on_delivery', true)
    );
  else
    update public.orders set status = p_new_status where id = p_order_id;
  end if;

  return true;
end;
$$;

revoke all on function private.update_order_status_by_shopkeeper(uuid,public.order_status) from public, anon;
grant execute on function private.update_order_status_by_shopkeeper(uuid,public.order_status) to authenticated;
