
do $$
declare
  t text;
  p record;
  shop_tables text[] := array[
    'digital_service_applications','electronics_inventory','electronics_service_jobs',
    'garment_product_variants','grocery_suppliers','grocery_stock_purchases',
    'grocery_supplier_payments','grocery_stock_movements','grocery_expenses',
    'hotel_booking_requests','hotel_housekeeping_tasks','hotel_reservations','hotel_rooms',
    'jewellery_product_details','medical_inventory_batches','office_attendance',
    'office_employees','office_leave_requests','office_payroll_records','office_tasks',
    'restaurant_kitchen_tickets','restaurant_menu_items','restaurant_reservations','restaurant_tables'
  ];
begin
  foreach t in array shop_tables loop
    for p in
      select policyname
      from pg_policies
      where schemaname='public' and tablename=t and cmd <> 'SELECT'
    loop
      execute format('drop policy %I on public.%I',p.policyname,t);
    end loop;

    execute format(
      'create policy shopkeeper_universal_insert on public.%I for insert to authenticated with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))',t
    );
    execute format(
      'create policy shopkeeper_universal_update on public.%I for update to authenticated using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id)) with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))',t
    );
    execute format(
      'create policy shopkeeper_universal_delete on public.%I for delete to authenticated using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))',t
    );
  end loop;

  for p in
    select policyname from pg_policies
    where schemaname='public' and tablename='restaurant_kitchen_ticket_items' and cmd <> 'SELECT'
  loop
    execute format('drop policy %I on public.restaurant_kitchen_ticket_items',p.policyname);
  end loop;
end $$;

create policy shopkeeper_universal_insert
on public.restaurant_kitchen_ticket_items for insert to authenticated
with check (exists (
  select 1 from public.restaurant_kitchen_tickets t
  where t.id=restaurant_kitchen_ticket_items.ticket_id
    and private.is_shop_owner(t.shop_id)
    and private.is_active_subscribed_shop(t.shop_id)
));

create policy shopkeeper_universal_update
on public.restaurant_kitchen_ticket_items for update to authenticated
using (exists (
  select 1 from public.restaurant_kitchen_tickets t
  where t.id=restaurant_kitchen_ticket_items.ticket_id
    and private.is_shop_owner(t.shop_id)
    and private.is_active_subscribed_shop(t.shop_id)
))
with check (exists (
  select 1 from public.restaurant_kitchen_tickets t
  where t.id=restaurant_kitchen_ticket_items.ticket_id
    and private.is_shop_owner(t.shop_id)
    and private.is_active_subscribed_shop(t.shop_id)
));

create policy shopkeeper_universal_delete
on public.restaurant_kitchen_ticket_items for delete to authenticated
using (exists (
  select 1 from public.restaurant_kitchen_tickets t
  where t.id=restaurant_kitchen_ticket_items.ticket_id
    and private.is_shop_owner(t.shop_id)
    and private.is_active_subscribed_shop(t.shop_id)
));

create policy electronics_service_jobs_public_insert
on public.electronics_service_jobs for insert to anon
with check (
  status='received' and inventory_id is null and diagnosis is null
  and estimated_cost is null and approved_cost is null and final_cost is null
  and delivered_at is null and customer_id is not distinct from auth.uid()
  and private.is_active_electronics_service_shop(shop_id)
);

create policy hotel_booking_requests_public_insert
on public.hotel_booking_requests for insert to anon
with check (
  status='pending' and reservation_id is null
  and customer_id is not distinct from auth.uid()
  and check_in >= current_date and check_out > check_in
  and check_out <= (current_date + 90)
  and private.is_active_hotel_booking_shop(shop_id)
);

create policy restaurant_reservations_public_insert
on public.restaurant_reservations for insert to anon
with check (
  status='pending' and table_id is null
  and customer_id is not distinct from auth.uid()
  and reservation_at >= (now() + interval '30 minutes')
  and reservation_at <= (now() + interval '90 days')
  and private.is_active_restaurant_booking_shop(shop_id)
);
