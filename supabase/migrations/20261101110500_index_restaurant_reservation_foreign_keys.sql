drop index if exists public.restaurant_reservations_shop_time_idx;
create index if not exists restaurant_reservations_shop_created_idx on public.restaurant_reservations(shop_id,created_at desc);
create index if not exists restaurant_reservations_customer_id_idx on public.restaurant_reservations(customer_id);
create index if not exists restaurant_reservations_shop_table_idx on public.restaurant_reservations(shop_id,table_id);
