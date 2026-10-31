drop policy if exists garment_variants_read on public.garment_product_variants;
create policy garment_variants_read on public.garment_product_variants for select to anon,authenticated
using(private.is_shop_owner(shop_id) or private.is_super_admin() or (is_available=true and private.is_public_shop_active(shop_id) and exists(select 1 from public.products p where p.id=garment_product_variants.product_id and p.shop_id=garment_product_variants.shop_id and p.is_available=true)));
