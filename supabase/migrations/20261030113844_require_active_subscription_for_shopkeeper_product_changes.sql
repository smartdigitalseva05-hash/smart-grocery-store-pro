
create or replace function public.check_product_limit_by_plan()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shop public.shops%rowtype;
  v_max integer;
  v_count integer;
  v_trusted boolean := public.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
begin
  select * into v_shop
  from public.shops
  where id = new.shop_id
  for key share;

  if not found then
    raise exception 'Shop not found' using errcode = 'P0002';
  end if;

  if not v_trusted and (
    v_shop.is_active is distinct from true
    or v_shop.status <> 'active'::public.shop_status
    or v_shop.subscription_expires_at is null
    or v_shop.subscription_expires_at <= now()
    or v_shop.subscription_plan_id is null
  ) then
    raise exception 'An active shop with a valid paid subscription is required to manage products'
      using errcode = '55000';
  end if;

  if v_trusted then
    return new;
  end if;

  select max_products into v_max
  from public.subscription_plans
  where id = v_shop.subscription_plan_id
    and is_active = true;

  if v_max is null then
    raise exception 'The shop subscription plan is unavailable'
      using errcode = '55000';
  end if;

  if tg_op = 'INSERT' or new.shop_id is distinct from old.shop_id then
    select count(*) into v_count
    from public.products
    where shop_id = new.shop_id
      and (tg_op = 'INSERT' or id is distinct from old.id);

    if v_count >= v_max then
      raise exception 'Product limit reached: %', v_max
        using errcode = '55000';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_product_limit on public.products;
create trigger trg_product_limit
before insert or update of shop_id, price, sale_price, stock, is_available
on public.products
for each row execute function public.check_product_limit_by_plan();

revoke all on function public.check_product_limit_by_plan() from public, anon, authenticated;
