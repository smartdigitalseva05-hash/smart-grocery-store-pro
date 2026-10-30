-- Categories: public reads, authenticated Super Admin writes.
drop policy if exists cat_admin on public.categories;
create policy cat_admin_insert on public.categories for insert to authenticated with check (private.is_super_admin());
create policy cat_admin_update on public.categories for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy cat_admin_delete on public.categories for delete to authenticated using (private.is_super_admin());

-- Products: keep read policy; shop owner/admin write policies are not SELECT policies.
drop policy if exists products_write on public.products;
create policy products_insert on public.products for insert to authenticated with check (private.is_shop_owner(shop_id) or private.is_super_admin());
create policy products_update on public.products for update to authenticated using (private.is_shop_owner(shop_id) or private.is_super_admin()) with check (private.is_shop_owner(shop_id) or private.is_super_admin());
create policy products_delete on public.products for delete to authenticated using (private.is_shop_owner(shop_id) or private.is_super_admin());

-- Order items: reads are scoped through parent order; writes only Super Admin.
drop policy if exists order_items_no_direct on public.order_items;
create policy order_items_admin_insert on public.order_items for insert to authenticated with check (private.is_super_admin());
create policy order_items_admin_update on public.order_items for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy order_items_admin_delete on public.order_items for delete to authenticated using (private.is_super_admin());

-- Shop subscriptions: owners can read own; only Super Admin can mutate directly.
drop policy if exists shop_subs_write on public.shop_subscriptions;
create policy shop_subs_admin_insert on public.shop_subscriptions for insert to authenticated with check (private.is_super_admin());
create policy shop_subs_admin_update on public.shop_subscriptions for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy shop_subs_admin_delete on public.shop_subscriptions for delete to authenticated using (private.is_super_admin());

-- Platform settings: public rows readable; authenticated Super Admin can manage.
drop policy if exists settings_admin on public.platform_settings;
create policy settings_admin_insert on public.platform_settings for insert to authenticated with check (private.is_super_admin());
create policy settings_admin_update on public.platform_settings for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy settings_admin_delete on public.platform_settings for delete to authenticated using (private.is_super_admin());

-- Subscription plans: public reads; authenticated Super Admin writes.
drop policy if exists plans_admin on public.subscription_plans;
create policy plans_admin_insert on public.subscription_plans for insert to authenticated with check (private.is_super_admin());
create policy plans_admin_update on public.subscription_plans for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy plans_admin_delete on public.subscription_plans for delete to authenticated using (private.is_super_admin());