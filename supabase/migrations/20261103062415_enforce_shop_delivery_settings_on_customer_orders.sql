create or replace function private.apply_shop_delivery_settings()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, private
as $$
declare
  v_settings public.shop_storefront_settings%rowtype;
  v_zone public.shop_delivery_zones%rowtype;
  v_has_settings boolean := false;
  v_active_zone_count integer := 0;
  v_fee numeric;
  v_pincode text;
begin
  select * into v_settings
  from public.shop_storefront_settings
  where shop_id = new.shop_id;
  v_has_settings := found;

  if not v_has_settings then
    return new;
  end if;

  if not v_settings.store_open then
    raise exception 'This shop is currently closed for online orders'
      using errcode = '55000';
  end if;

  if not v_settings.delivery_enabled then
    raise exception 'Home delivery is currently disabled by this shop'
      using errcode = '55000';
  end if;

  if new.subtotal < v_settings.minimum_order_amount then
    raise exception 'Minimum order amount is %', v_settings.minimum_order_amount
      using errcode = '22023';
  end if;

  select count(*) into v_active_zone_count
  from public.shop_delivery_zones
  where shop_id = new.shop_id and is_active = true;

  v_pincode := new.shipping_address ->> 'pincode';

  if v_active_zone_count > 0 then
    select * into v_zone
    from public.shop_delivery_zones
    where shop_id = new.shop_id
      and pincode = v_pincode
      and is_active = true
    limit 1;

    if not found then
      raise exception 'This shop does not deliver to pincode %', coalesce(v_pincode, 'unknown')
        using errcode = '22023';
    end if;

    if new.subtotal < v_zone.minimum_order_amount then
      raise exception 'Minimum order for this delivery area is %', v_zone.minimum_order_amount
        using errcode = '22023';
    end if;

    v_fee := v_zone.delivery_fee;
  else
    v_fee := v_settings.delivery_fee;
  end if;

  if v_settings.free_delivery_threshold is not null
     and new.subtotal >= v_settings.free_delivery_threshold then
    v_fee := 0;
  end if;

  if v_fee < 0 then
    raise exception 'Invalid shop delivery fee' using errcode = '22023';
  end if;

  new.shipping_fee := v_fee;
  new.total := new.subtotal + v_fee;
  return new;
end;
$$;

drop trigger if exists orders_apply_shop_delivery_settings on public.orders;
create trigger orders_apply_shop_delivery_settings
before insert on public.orders
for each row
execute function private.apply_shop_delivery_settings();