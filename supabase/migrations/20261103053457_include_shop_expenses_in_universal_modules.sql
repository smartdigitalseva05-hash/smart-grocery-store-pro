
create policy shopkeeper_all_modules_shop_scope
on public.grocery_expenses
for all to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
