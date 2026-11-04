
create or replace function private.is_active_subscribed_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.shops s
    join public.profiles p on p.id = s.owner_id
    where s.id = p_shop_id
      and s.owner_id = auth.uid()
      and s.is_active = true
      and s.status = 'active'::public.shop_status
      and s.subscription_expires_at > pg_catalog.now()
      and p.role = 'shopkeeper'::public.user_role
      and p.is_active = true
  );
$$;

revoke all on function private.is_active_subscribed_shop(uuid) from public, anon;
grant execute on function private.is_active_subscribed_shop(uuid) to authenticated;

do $$
declare
  t text;
  shop_tables text[] := array[
    'digital_service_applications',
    'electronics_inventory',
    'electronics_service_jobs',
    'garment_product_variants',
    'grocery_suppliers',
    'grocery_stock_purchases',
    'grocery_supplier_payments',
    'grocery_stock_movements',
    'hotel_booking_requests',
    'hotel_housekeeping_tasks',
    'hotel_reservations',
    'hotel_rooms',
    'jewellery_product_details',
    'medical_inventory_batches',
    'office_attendance',
    'office_employees',
    'office_leave_requests',
    'office_payroll_records',
    'office_tasks',
    'restaurant_kitchen_tickets',
    'restaurant_menu_items',
    'restaurant_reservations',
    'restaurant_tables'
  ];
begin
  foreach t in array shop_tables loop
    execute format(
      'create policy %I on public.%I for all to authenticated using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id)) with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))',
      'shopkeeper_all_modules_shop_scope', t
    );
  end loop;
end $$;

create policy shopkeeper_all_modules_shop_scope
on public.restaurant_kitchen_ticket_items
for all to authenticated
using (
  exists (
    select 1 from public.restaurant_kitchen_tickets t
    where t.id = restaurant_kitchen_ticket_items.ticket_id
      and private.is_shop_owner(t.shop_id)
      and private.is_active_subscribed_shop(t.shop_id)
  )
)
with check (
  exists (
    select 1 from public.restaurant_kitchen_tickets t
    where t.id = restaurant_kitchen_ticket_items.ticket_id
      and private.is_shop_owner(t.shop_id)
      and private.is_active_subscribed_shop(t.shop_id)
  )
);
