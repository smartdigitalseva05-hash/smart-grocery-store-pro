drop policy if exists product_reviews_customer_read_own on public.shop_product_reviews;
create policy product_reviews_customer_read_own
on public.shop_product_reviews
for select
to authenticated
using (customer_id = (select auth.uid()));