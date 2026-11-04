grant select on public.products to anon;
drop policy if exists products_public_storefront_read on public.products;
create policy products_public_storefront_read on public.products for select to anon using (
 is_available = true and private.is_public_shop_active(shop_id)
);