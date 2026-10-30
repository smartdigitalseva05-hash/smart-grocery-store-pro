CREATE OR REPLACE FUNCTION private.create_subscription_checkout(p_shop_id uuid, p_plan_id uuid, p_billing_cycle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop public.shops%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_existing record;
  v_amount numeric;
  v_starts timestamptz;
  v_ends timestamptz;
  v_sub_id uuid;
  v_payment_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_uid
      and role = 'shopkeeper'::public.user_role
      and is_active = true
  ) then
    raise exception 'Active shopkeeper account required' using errcode = '42501';
  end if;

  if p_shop_id is null
     or p_plan_id is null
     or p_billing_cycle is null
     or p_billing_cycle not in ('monthly','yearly') then
    raise exception 'Shop, plan and monthly/yearly billing cycle are required'
      using errcode = '22023';
  end if;

  select * into v_shop
  from public.shops
  where id = p_shop_id and owner_id = v_uid
  for update;

  if not found then
    raise exception 'Shop not found or not owned by this account'
      using errcode = '42501';
  end if;

  if v_shop.status = 'suspended'::public.shop_status then
    raise exception 'Suspended shops cannot purchase a subscription'
      using errcode = '55000';
  end if;

  select ss.id as subscription_id, ss.plan_id, ss.billing_cycle, ss.starts_at, ss.ends_at,
         p.id as payment_id, p.amount, p.status as payment_status, p.gateway_order_id
  into v_existing
  from public.shop_subscriptions ss
  join public.payments p on p.id = ss.payment_id
  where ss.shop_id = p_shop_id
    and ss.status = 'pending_payment'::public.subscription_status
  order by ss.created_at desc
  limit 1
  for update of ss, p;

  if found then
    if v_existing.plan_id = p_plan_id
       and v_existing.billing_cycle = p_billing_cycle
       and v_existing.payment_status = 'pending'::public.payment_status then
      return jsonb_build_object(
        'subscription_id', v_existing.subscription_id,
        'payment_id', v_existing.payment_id,
        'amount', v_existing.amount,
        'currency', 'INR',
        'billing_cycle', v_existing.billing_cycle,
        'starts_at', v_existing.starts_at,
        'ends_at', v_existing.ends_at,
        'gateway', 'razorpay',
        'gateway_order_id', v_existing.gateway_order_id,
        'payment_status', 'pending',
        'reused', true
      );
    end if;
    raise exception 'A different pending subscription payment exists. Complete it or contact support before selecting another plan'
      using errcode = '55000';
  end if;

  select * into v_plan
  from public.subscription_plans
  where id = p_plan_id and is_active = true;

  if not found then
    raise exception 'Selected plan is unavailable' using errcode = '22023';
  end if;

  if p_billing_cycle = 'monthly' then
    v_amount := v_plan.price_monthly;
  else
    v_amount := v_plan.price_yearly;
  end if;

  if v_amount is null or v_amount <= 0 then
    raise exception 'Selected plan has no valid price' using errcode = '22023';
  end if;

  v_starts := greatest(now(), coalesce(v_shop.subscription_expires_at, now()));
  if p_billing_cycle = 'monthly' then
    v_ends := v_starts + interval '1 month';
  else
    v_ends := v_starts + interval '1 year';
  end if;

  insert into public.shop_subscriptions(shop_id, plan_id, status, starts_at, ends_at, billing_cycle)
  values (p_shop_id, p_plan_id, 'pending_payment'::public.subscription_status, v_starts, v_ends, p_billing_cycle)
  returning id into v_sub_id;

  insert into public.payments(
    shop_subscription_id, user_id, amount, currency, status, gateway, verified
  )
  values (
    v_sub_id, v_uid, v_amount, 'INR', 'pending'::public.payment_status, 'razorpay', false
  )
  returning id into v_payment_id;

  update public.shop_subscriptions
  set payment_id = v_payment_id
  where id = v_sub_id;

  insert into public.audit_logs(actor_id, action, entity, entity_id, new_data)
  values (
    v_uid,
    'subscription'::public.audit_action,
    'shop_subscriptions',
    v_sub_id,
    jsonb_build_object(
      'shop_id', p_shop_id,
      'plan_id', p_plan_id,
      'billing_cycle', p_billing_cycle,
      'amount', v_amount,
      'currency', 'INR',
      'payment_id', v_payment_id
    )
  );

  return jsonb_build_object(
    'subscription_id', v_sub_id,
    'payment_id', v_payment_id,
    'amount', v_amount,
    'currency', 'INR',
    'billing_cycle', p_billing_cycle,
    'starts_at', v_starts,
    'ends_at', v_ends,
    'gateway', 'razorpay',
    'gateway_order_id', null,
    'payment_status', 'pending',
    'reused', false
  );
end;
$function$


ALTER TABLE public.shop_subscriptions ALTER COLUMN billing_cycle SET NOT NULL;
