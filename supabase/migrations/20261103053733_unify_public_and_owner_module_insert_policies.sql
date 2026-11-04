
drop policy shopkeeper_universal_insert on public.electronics_service_jobs;
drop policy shopkeeper_universal_insert on public.hotel_booking_requests;
drop policy shopkeeper_universal_insert on public.restaurant_reservations;

drop policy electronics_service_jobs_public_insert on public.electronics_service_jobs;
create policy electronics_service_jobs_public_insert
on public.electronics_service_jobs for insert to anon, authenticated
with check (
  (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
  or (
    status='received' and inventory_id is null and diagnosis is null
    and estimated_cost is null and approved_cost is null and final_cost is null
    and delivered_at is null and customer_id is not distinct from auth.uid()
    and private.is_active_electronics_service_shop(shop_id)
  )
);

drop policy hotel_booking_requests_public_insert on public.hotel_booking_requests;
create policy hotel_booking_requests_public_insert
on public.hotel_booking_requests for insert to anon, authenticated
with check (
  (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
  or (
    status='pending' and reservation_id is null
    and customer_id is not distinct from auth.uid()
    and check_in >= current_date and check_out > check_in
    and check_out <= (current_date + 90)
    and private.is_active_hotel_booking_shop(shop_id)
  )
);

drop policy restaurant_reservations_public_insert on public.restaurant_reservations;
create policy restaurant_reservations_public_insert
on public.restaurant_reservations for insert to anon, authenticated
with check (
  (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
  or (
    status='pending' and table_id is null
    and customer_id is not distinct from auth.uid()
    and reservation_at >= (now() + interval '30 minutes')
    and reservation_at <= (now() + interval '90 days')
    and private.is_active_restaurant_booking_shop(shop_id)
  )
);
