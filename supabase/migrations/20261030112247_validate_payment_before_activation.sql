
create or replace function public.verify_payment_and_activate(p_payment_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_pay public.payments%rowtype;
  v_sub public.shop_subscriptions%rowtype;
  v_shop public.shops%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_order public.orders%rowtype;
begin
  if auth.uid() is null or not public.is_super_admin() then
    raise exception 'Only active Super Admin can verify payments'
      using errcode = '42501';
  end if;

  if p_payment_id is null then
    raise exception 'Payment ID is required' using errcode = '22023';
  end if;

  select * into v_pay
  from public.payments
  where id = p_payment_id
  for update;

  if not found then
    raise exception 'Payment not found' using errcode = 'P0002';
  end if;

  if v_pay.verified then
    return true;
  end if;

  if v_pay.status <> 'success'::public.payment_status
     or v_pay.currency <> 'INR'
     or v_pay.amount <= 0
     or ((v_pay.order_id is null) = (v_pay.shop_subscription_id is null)) then
    raise exception 'Payment is not a valid successful INR payment'
      using errcode = '55000';
  end if;

  if v_pay.shop_subscription_id is not null then
    select * into v_sub
    from public.shop_subscriptions
    where id = v_pay.shop_subscription_id
    for update;

    if not found then
      raise exception 'Subscription record not found' using errcode = 'P0002';
    end if;

    select * into v_shop
    from public.shops
    where id = v_sub.shop_id
    for update;

    if not found or v_shop.owner_id is distinct from v_pay.user_id then
      raise exception 'Payment user does not own this shop'
        using errcode = '42501';
    end if;

    select * into v_plan
    from public.subscription_plans
    where id = v_sub.plan_id;

    if not found then
      raise exception 'Subscription plan not found' using errcode = 'P0002';
    end if;

    if v_pay.amount not in (v_plan.price_monthly, v_plan.price_yearly) then
      raise exception 'Payment amount does not match the selected subscription plan'
        using errcode = '22023';
    end if;

    if v_sub.ends_at is null or v_sub.ends_at <= now()
       or (v_sub.starts_at is not null and v_sub.ends_at <= v_sub.starts_at) then
      raise exception 'Subscription dates are invalid or expired'
        using errcode = '22023';
    end if;

    update public.payments set verified = true where id = p_payment_id;

    update public.shop_subscriptions
    set status = 'active'::public.subscription_status,
        payment_id = p_payment_id
    where id = v_sub.id;

    update public.shops
    set is_active = true,
        status = 'active'::public.shop_status,
        subscription_plan_id = v_sub.plan_id,
        subscription_expires_at = v_sub.ends_at
    where id = v_shop.id;

  else
    select * into v_order
    from public.orders
    where id = v_pay.order_id
    for update;

    if not found then
      raise exception 'Order not found' using errcode = 'P0002';
    end if;

    if v_order.customer_id is distinct from v_pay.user_id
       or v_order.status <> 'pending'::public.order_status
       or v_order.total <> v_pay.amount then
      raise exception 'Payment does not match the pending customer order'
        using errcode = '22023';
    end if;

    update public.payments set verified = true where id = p_payment_id;
    update public.orders set status = 'paid'::public.order_status where id = v_order.id;
  end if;

  return true;
end;
$$;

revoke all on function public.verify_payment_and_activate(uuid) from public, anon;
grant execute on function public.verify_payment_and_activate(uuid) to authenticated;
