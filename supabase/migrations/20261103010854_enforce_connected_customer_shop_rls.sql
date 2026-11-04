
create or replace function private.enforce_customer_shop_binding()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.connected_shop_id is not null
     and new.connected_shop_id is distinct from old.connected_shop_id
     and not private.is_super_admin() then
    raise exception using
      errcode = '23514',
      message = 'This customer account is permanently connected to its original shop.';
  end if;

  if old.connected_shop_id is null and new.connected_shop_id is not null
     and not private.is_super_admin() then
    if new.role <> 'customer' then
      raise exception using
        errcode = '42501',
        message = 'Only customer accounts can connect to a shop.';
    end if;

    if auth.uid() is null or auth.uid() <> new.id then
      raise exception using
        errcode = '42501',
        message = 'Customers can connect only their own account.';
    end if;
  end if;

  if new.connected_shop_id is not null
     and not private.is_public_shop_active(new.connected_shop_id) then
    raise exception using
      errcode = '23514',
      message = 'This shop is not active and cannot accept customer connections.';
  end if;

  return new;
end;
$$;

alter policy shops_read_authenticated on public.shops
using (
  private.is_super_admin()
  or private.is_shop_owner(id)
  or (
    id = (select p.connected_shop_id
          from public.profiles p
          where p.id = (select auth.uid()))
    and private.is_public_shop_active(id)
  )
);

alter policy products_read_authenticated on public.products
using (
  private.is_super_admin()
  or private.is_shop_owner(shop_id)
  or (
    shop_id = (select p.connected_shop_id
               from public.profiles p
               where p.id = (select auth.uid()))
    and private.is_public_shop_active(shop_id)
  )
);

drop policy if exists products_read_public on public.products;
