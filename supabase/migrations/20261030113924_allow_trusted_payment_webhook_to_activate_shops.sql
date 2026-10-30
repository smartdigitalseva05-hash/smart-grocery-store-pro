
create or replace function public.prevent_shop_expiry_tamper()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_trusted boolean := public.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
begin
  if tg_op = 'UPDATE'
     and old.subscription_expires_at is distinct from new.subscription_expires_at
     and not v_trusted then
    raise exception 'Subscription expiry can only be changed by the trusted payment process or active Super Admin'
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
  v_trusted boolean := public.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
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
    raise exception 'Only trusted payment process or active Super Admin can change shop activation and subscription fields'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_shop_expiry_tamper() from public, anon, authenticated;
revoke all on function public.guard_shop_activation_fields() from public, anon, authenticated;
