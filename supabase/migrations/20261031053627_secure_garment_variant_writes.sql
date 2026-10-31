drop policy if exists garment_variants_insert on public.garment_product_variants;
create policy garment_variants_insert on public.garment_product_variants for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=garment_product_variants.shop_id and s.business_type='garments' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.products p where p.id=garment_product_variants.product_id and p.shop_id=garment_product_variants.shop_id));
drop policy if exists garment_variants_update on public.garment_product_variants;
create policy garment_variants_update on public.garment_product_variants for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=garment_product_variants.shop_id and s.business_type='garments' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=garment_product_variants.shop_id and s.business_type='garments' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.products p where p.id=garment_product_variants.product_id and p.shop_id=garment_product_variants.shop_id));
drop policy if exists garment_variants_delete on public.garment_product_variants;
create policy garment_variants_delete on public.garment_product_variants for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=garment_product_variants.shop_id and s.business_type='garments' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
