create or replace function private.guard_hotel_reservation_room_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare linked_shop uuid;
begin
  select shop_id into linked_shop from public.hotel_rooms where id = new.room_id;
  if linked_shop is not null and linked_shop is distinct from new.shop_id then
    raise exception 'Reservation room must belong to the same business'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.guard_office_attendance_employee_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare linked_shop uuid;
begin
  select shop_id into linked_shop from public.office_employees where id = new.employee_id;
  if linked_shop is not null and linked_shop is distinct from new.shop_id then
    raise exception 'Attendance employee must belong to the same business'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.guard_restaurant_ticket_table_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare linked_shop uuid;
begin
  if new.table_id is not null then
    select shop_id into linked_shop from public.restaurant_tables where id = new.table_id;
    if linked_shop is not null and linked_shop is distinct from new.shop_id then
      raise exception 'Restaurant table must belong to the same business'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.guard_restaurant_ticket_item_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare ticket_shop uuid;
declare menu_shop uuid;
begin
  select shop_id into ticket_shop from public.restaurant_kitchen_tickets where id = new.ticket_id;
  if new.menu_item_id is not null then
    select shop_id into menu_shop from public.restaurant_menu_items where id = new.menu_item_id;
    if ticket_shop is not null and menu_shop is not null and ticket_shop is distinct from menu_shop then
      raise exception 'Kitchen ticket menu item must belong to the same business'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_hotel_reservation_room_shop on public.hotel_reservations;
create trigger guard_hotel_reservation_room_shop
before insert or update of shop_id, room_id on public.hotel_reservations
for each row execute function private.guard_hotel_reservation_room_shop();

drop trigger if exists guard_office_attendance_employee_shop on public.office_attendance;
create trigger guard_office_attendance_employee_shop
before insert or update of shop_id, employee_id on public.office_attendance
for each row execute function private.guard_office_attendance_employee_shop();

drop trigger if exists guard_restaurant_ticket_table_shop on public.restaurant_kitchen_tickets;
create trigger guard_restaurant_ticket_table_shop
before insert or update of shop_id, table_id on public.restaurant_kitchen_tickets
for each row execute function private.guard_restaurant_ticket_table_shop();

drop trigger if exists guard_restaurant_ticket_item_shop on public.restaurant_kitchen_ticket_items;
create trigger guard_restaurant_ticket_item_shop
before insert or update of ticket_id, menu_item_id on public.restaurant_kitchen_ticket_items
for each row execute function private.guard_restaurant_ticket_item_shop();
