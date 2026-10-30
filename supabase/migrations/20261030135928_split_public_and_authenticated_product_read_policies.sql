
drop policy if exists products_read on public.products;
drop policy if exists products_read_public on public.products;
drop policy if exists products_read_authenticated on public.products;

create policy products_read_public
on public.products
for select
to anon
using (
  exists (
    select 1
    from public.shops s
    where s.id = products.shop_id
      and s.is_active = true
  )
);

create policy products_read_authenticated
on public.products
for select
to authenticated
using (
  exists (
    select 1
    from public.shops s
    where s.id = products.shop_id
      and s.is_active = true
  )
  or private.is_shop_owner(shop_id)
  or private.is_super_admin()
);
