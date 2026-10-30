alter policy addr_owner on public.delivery_addresses
using ((user_id = (select auth.uid())) or private.is_super_admin())
with check ((user_id = (select auth.uid())) or private.is_super_admin());

alter policy order_items_read on public.order_items
using (exists (
  select 1 from public.orders o
  where o.id = order_items.order_id
    and (o.customer_id = (select auth.uid()) or private.is_shop_owner(o.shop_id) or private.is_super_admin())
));

alter policy history_read on public.order_status_history
using (exists (
  select 1 from public.orders o
  where o.id = order_status_history.order_id
    and (o.customer_id = (select auth.uid()) or private.is_shop_owner(o.shop_id) or private.is_super_admin())
));

alter policy orders_select on public.orders
using ((customer_id = (select auth.uid())) or private.is_shop_owner(shop_id) or private.is_super_admin());

alter policy orders_update on public.orders
using (private.is_shop_owner(shop_id) or private.is_super_admin() or customer_id = (select auth.uid()))
with check (private.is_shop_owner(shop_id) or private.is_super_admin() or customer_id = (select auth.uid()));

alter policy payments_insert_own on public.payments
with check (user_id = (select auth.uid()) and verified = false);

alter policy payments_read on public.payments
using (
  user_id = (select auth.uid())
  or private.is_super_admin()
  or exists (
    select 1 from public.orders o
    where o.id = payments.order_id and private.is_shop_owner(o.shop_id)
  )
);

alter policy profiles_self on public.profiles
using ((id = (select auth.uid())) or private.is_super_admin());

alter policy profiles_update_own on public.profiles
using ((id = (select auth.uid())) or private.is_super_admin())
with check ((id = (select auth.uid())) or private.is_super_admin());

alter policy shops_insert on public.shops
with check (owner_id = (select auth.uid()));

alter policy shops_read on public.shops
using ((is_active = true) or owner_id = (select auth.uid()) or private.is_super_admin());

alter policy shops_update on public.shops
using ((owner_id = (select auth.uid())) or private.is_super_admin())
with check ((owner_id = (select auth.uid())) or private.is_super_admin());