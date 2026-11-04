alter table public.orders
  add column if not exists coupon_code text,
  add column if not exists discount_amount numeric not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.orders'::regclass
      and conname = 'orders_discount_amount_valid'
  ) then
    alter table public.orders
      add constraint orders_discount_amount_valid
      check (discount_amount >= 0 and discount_amount <= subtotal);
  end if;
end $$;

create or replace function private.place_order_with_coupon(
  p_shop_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_notes text default null,
  p_coupon_code text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_order_id uuid;
  v_coupon public.shop_coupons%rowtype;
  v_subtotal numeric;
  v_discount numeric := 0;
  v_code text := nullif(upper(btrim(coalesce(p_coupon_code, ''))), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_order_id := private.place_order_with_notes(p_shop_id, p_address_id, p_items, p_notes);

  if v_code is null then
    return v_order_id;
  end if;

  select * into v_coupon
  from public.shop_coupons
  where shop_id = p_shop_id
    and code = v_code
    and is_active = true
  for update;

  if not found then
    raise exception 'Coupon code is invalid or inactive' using errcode = '22023';
  end if;

  if v_coupon.starts_at is not null and now() < v_coupon.starts_at then
    raise exception 'This coupon is not active yet' using errcode = '22023';
  end if;
  if v_coupon.ends_at is not null and now() > v_coupon.ends_at then
    raise exception 'This coupon has expired' using errcode = '22023';
  end if;
  if v_coupon.usage_limit is not null and v_coupon.used_count >= v_coupon.usage_limit then
    raise exception 'This coupon has reached its usage limit' using errcode = '22023';
  end if;

  select subtotal into v_subtotal
  from public.orders
  where id = v_order_id and customer_id = auth.uid() and shop_id = p_shop_id;

  if not found then
    raise exception 'Order could not be verified for coupon redemption' using errcode = '42501';
  end if;
  if v_subtotal < v_coupon.minimum_order_amount then
    raise exception 'Minimum order for this coupon is %', v_coupon.minimum_order_amount using errcode = '22023';
  end if;

  if v_coupon.discount_type = 'percentage' then
    v_discount := v_subtotal * v_coupon.discount_value / 100;
  else
    v_discount := v_coupon.discount_value;
  end if;
  if v_coupon.maximum_discount is not null then
    v_discount := least(v_discount, v_coupon.maximum_discount);
  end if;
  v_discount := least(v_discount, v_subtotal);

  if v_discount <= 0 then
    raise exception 'Coupon discount is not valid for this order' using errcode = '22023';
  end if;

  update public.orders
  set coupon_code = v_code,
      discount_amount = v_discount,
      total = greatest(0, total - v_discount)
  where id = v_order_id and customer_id = auth.uid();

  update public.shop_coupons
  set used_count = used_count + 1,
      updated_at = now()
  where id = v_coupon.id;

  return v_order_id;
end;
$$;

revoke all on function private.place_order_with_coupon(uuid,uuid,jsonb,text,text) from public, anon;
grant execute on function private.place_order_with_coupon(uuid,uuid,jsonb,text,text) to authenticated;

create or replace function public.place_order_with_coupon(
  p_shop_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_notes text default null,
  p_coupon_code text default null
)
returns uuid
language sql
set search_path = pg_catalog, public, private
as $$
  select private.place_order_with_coupon(p_shop_id, p_address_id, p_items, p_notes, p_coupon_code);
$$;

revoke all on function public.place_order_with_coupon(uuid,uuid,jsonb,text,text) from public, anon;
grant execute on function public.place_order_with_coupon(uuid,uuid,jsonb,text,text) to authenticated;