CREATE OR REPLACE FUNCTION private.verify_payment_and_activate(p_payment_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_pay public.payments%rowtype;
  v_sub public.shop_subscriptions%rowtype;
  v_shop public.shops%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_profile public.profiles%rowtype;
  v_order public.orders%rowtype;
  v_service_role boolean := coalesce(auth.jwt() ->> 'role', '') = 'service_role';
  v_expected_amount numeric;
begin
  if not v_service_role and (auth.uid() is null or not private.is_super_admin()) then
    raise exception 'Only the trusted payment process or active Super Admin can verify payments'
      using errcode = '42501';
  end if;

  if p_payment_id is null then
    raise exception 'Payment ID is required' using errcode = '22023';
  end if;

  select * into v_pay from public.payments where id = p_payment_id for update;
  if not found then raise exception 'Payment not found' using errcode = 'P0002'; end if;
  if v_pay.verified then return true; end if;

  if v_pay.status <> 'success'::public.payment_status
     or v_pay.gateway <> 'razorpay'
     or v_pay.gateway_order_id is null
     or v_pay.gateway_transaction_id is null
     or coalesce(v_pay.gateway_payload ->> 'captured', 'false') <> 'true'
     or v_pay.gateway_payload ->> 'razorpay_order_id' is distinct from v_pay.gateway_order_id
     or v_pay.gateway_payload ->> 'razorpay_payment_id' is distinct from v_pay.gateway_transaction_id
     or not (
       coalesce(v_pay.gateway_payload ->> 'signature_verified', 'false') = 'true'
       or coalesce(v_pay.gateway_payload ->> 'webhook_signature_verified', 'false') = 'true'
     )
     or v_pay.currency <> 'INR'
     or v_pay.amount <= 0
     or ((v_pay.order_id is null) = (v_pay.shop_subscription_id is null)) then
    raise exception 'Payment lacks verified Razorpay capture details' using errcode = '55000';
  end if;

  if v_pay.shop_subscription_id is not null then
    select * into v_sub from public.shop_subscriptions
    where id = v_pay.shop_subscription_id for update;
    if not found then raise exception 'Subscription record not found' using errcode = 'P0002'; end if;

    if v_sub.payment_id is distinct from p_payment_id
       or v_sub.status <> 'pending_payment'::public.subscription_status then
      raise exception 'Subscription is not in a payable pending state' using errcode = '55000';
    end if;

    select * into v_shop from public.shops where id = v_sub.shop_id for update;
    if not found or v_shop.owner_id is distinct from v_pay.user_id then
      raise exception 'Payment user does not own this shop' using errcode = '42501';
    end if;

    if v_shop.status = 'suspended'::public.shop_status then
      raise exception 'Suspended shops cannot be activated by a payment callback; owner review is required' using errcode = '55000';
    end if;

    select * into v_profile from public.profiles where id = v_pay.user_id for update;
    if not found
       or v_profile.role <> 'shopkeeper'::public.user_role
       or v_profile.is_active is distinct from true then
      raise exception 'Shopkeeper approval or active account is missing; owner review is required' using errcode = '42501';
    end if;

    select * into v_plan from public.subscription_plans
    where id = v_sub.plan_id and is_active = true;
    if not found then raise exception 'Subscription plan is unavailable' using errcode = 'P0002'; end if;

    if v_sub.billing_cycle = 'monthly' then
      v_expected_amount := v_plan.price_monthly;
    elsif v_sub.billing_cycle = 'yearly' then
      v_expected_amount := v_plan.price_yearly;
    else
      raise exception 'Subscription billing cycle is invalid' using errcode = '22023';
    end if;

    if v_expected_amount is null or v_pay.amount <> v_expected_amount then
      raise exception 'Payment amount does not match the selected plan and billing cycle' using errcode = '22023';
    end if;

    if v_sub.ends_at is null or v_sub.ends_at <= now()
       or (v_sub.starts_at is not null and v_sub.ends_at <= v_sub.starts_at) then
      raise exception 'Subscription dates are invalid or expired' using errcode = '22023';
    end if;

    update public.payments set verified = true where id = p_payment_id;
    update public.shop_subscriptions
    set status = 'active'::public.subscription_status, payment_id = p_payment_id
    where id = v_sub.id;
    update public.shops
    set is_active = true, status = 'active'::public.shop_status,
        subscription_plan_id = v_sub.plan_id, subscription_expires_at = v_sub.ends_at
    where id = v_shop.id;
  else
    select * into v_order from public.orders where id = v_pay.order_id for update;
    if not found then raise exception 'Order not found' using errcode = 'P0002'; end if;
    if v_order.customer_id is distinct from v_pay.user_id
       or v_order.status <> 'pending'::public.order_status
       or v_order.total <> v_pay.amount then
      raise exception 'Payment does not match the pending customer order' using errcode = '22023';
    end if;
    update public.payments set verified = true where id = p_payment_id;
    update public.orders set status = 'paid'::public.order_status where id = v_order.id;
  end if;

  return true;
end;
$function$;
