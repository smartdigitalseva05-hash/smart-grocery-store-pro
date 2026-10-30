
create extension if not exists pg_cron;

create or replace function public.check_subscription_expiry()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count integer := 0;
begin
  perform set_config('app.subscription_expiry_job', 'true', true);

  update public.shops
  set is_active = false,
      status = 'inactive'::public.shop_status
  where subscription_expires_at is not null
    and subscription_expires_at <= now()
    and is_active = true
    and status = 'active'::public.shop_status;

  get diagnostics v_count = row_count;

  update public.shop_subscriptions
  set status = 'expired'::public.subscription_status
  where ends_at <= now()
    and status = 'active'::public.subscription_status;

  return v_count;
end;
$$;

create or replace function public.prevent_shop_expiry_tamper()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_trusted boolean :=
    private.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
    or coalesce(current_setting('app.subscription_expiry_job', true), 'false') = 'true';
begin
  if tg_op = 'UPDATE'
     and old.subscription_expires_at is distinct from new.subscription_expires_at
     and not v_trusted then
    raise exception 'Subscription expiry can only be changed by the trusted payment process, expiry scheduler or active Super Admin'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.guard_shop_activation_fields()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_trusted boolean :=
    private.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
    or coalesce(current_setting('app.subscription_expiry_job', true), 'false') = 'true';
begin
  if v_trusted then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.is_active := false;
    new.status := 'inactive'::public.shop_status;
    new.subscription_plan_id := null;
    new.subscription_expires_at := null;
    return new;
  end if;

  if old.is_active is distinct from new.is_active
     or old.status is distinct from new.status
     or old.subscription_plan_id is distinct from new.subscription_plan_id
     or old.subscription_expires_at is distinct from new.subscription_expires_at then
    raise exception 'Only trusted payment process, expiry scheduler or active Super Admin can change shop activation and subscription fields'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function public.check_subscription_expiry() from public, anon, authenticated, service_role;

select cron.unschedule(jobid)
from cron.job
where jobname = 'expire-shop-subscriptions-hourly';

select cron.schedule(
  'expire-shop-subscriptions-hourly',
  '0 * * * *',
  'select public.check_subscription_expiry();'
);
