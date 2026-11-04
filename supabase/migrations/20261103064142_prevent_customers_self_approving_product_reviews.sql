drop policy if exists product_reviews_customer_insert on public.shop_product_reviews;
create policy product_reviews_customer_insert
on public.shop_product_reviews
for insert
to authenticated
with check (
  customer_id = (select auth.uid())
  and is_approved = false
  and exists (
    select 1
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.id = shop_product_reviews.order_id
      and o.shop_id = shop_product_reviews.shop_id
      and o.customer_id = (select auth.uid())
      and o.status = 'delivered'
      and oi.product_id = shop_product_reviews.product_id
  )
  and private.is_public_shop_active(shop_id)
);