drop policy if exists product_reviews_customer_read_own on public.shop_product_reviews;
drop policy if exists product_reviews_read on public.shop_product_reviews;
create policy product_reviews_read
on public.shop_product_reviews
for select
to authenticated
using (
  customer_id = (select auth.uid())
  or (is_approved and private.is_public_shop_active(shop_id))
  or private.is_shop_owner(shop_id)
);