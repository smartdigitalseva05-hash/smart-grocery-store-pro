drop policy if exists products_insert on public.products;
create policy products_insert on public.products for insert to authenticated
with check(private.is_super_admin() or (private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=products.shop_id and s.is_active=true and s.status='active' and s.subscription_expires_at>now())));
drop policy if exists products_update on public.products;
create policy products_update on public.products for update to authenticated
using(private.is_super_admin() or (private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=products.shop_id and s.is_active=true and s.status='active' and s.subscription_expires_at>now())))
with check(private.is_super_admin() or (private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=products.shop_id and s.is_active=true and s.status='active' and s.subscription_expires_at>now())));
drop policy if exists products_delete on public.products;
create policy products_delete on public.products for delete to authenticated
using(private.is_super_admin() or (private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=products.shop_id and s.is_active=true and s.status='active' and s.subscription_expires_at>now())));
