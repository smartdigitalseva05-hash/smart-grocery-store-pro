
drop policy if exists storefront_settings_owner_write on public.shop_storefront_settings;
create policy storefront_settings_owner_insert on public.shop_storefront_settings for insert to authenticated
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id) and (updated_by is null or updated_by = (select auth.uid())));
create policy storefront_settings_owner_update on public.shop_storefront_settings for update to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id) and (updated_by is null or updated_by = (select auth.uid())));
create policy storefront_settings_owner_delete on public.shop_storefront_settings for delete to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

drop policy if exists delivery_zones_owner_write on public.shop_delivery_zones;
create policy delivery_zones_owner_insert on public.shop_delivery_zones for insert to authenticated
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
create policy delivery_zones_owner_update on public.shop_delivery_zones for update to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
create policy delivery_zones_owner_delete on public.shop_delivery_zones for delete to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

create index if not exists shop_product_reviews_customer_idx on public.shop_product_reviews(customer_id);
create index if not exists shop_storefront_settings_updated_by_idx on public.shop_storefront_settings(updated_by);
