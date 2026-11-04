
grant select on public.shop_storefront_settings, public.shop_delivery_zones to anon;
drop policy if exists storefront_settings_public_read on public.shop_storefront_settings;
create policy storefront_settings_public_read on public.shop_storefront_settings for select to anon
using (private.is_public_shop_active(shop_id));
drop policy if exists delivery_zones_public_read on public.shop_delivery_zones;
create policy delivery_zones_public_read on public.shop_delivery_zones for select to anon
using (is_active and private.is_public_shop_active(shop_id));
