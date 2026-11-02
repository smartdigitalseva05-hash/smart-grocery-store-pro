-- Keep hotel room status consistent with checked-in reservations.
-- A room can only leave "occupied" after the reservation has been checked out.
create or replace function private.guard_hotel_room_checked_in_status()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $function$
begin
  if new.room_status is distinct from old.room_status
     and new.room_status <> 'occupied'
     and exists (
       select 1
       from public.hotel_reservations r
       where r.room_id = new.id
         and r.shop_id = new.shop_id
         and r.status = 'checked_in'
     ) then
    raise exception 'Room status cannot be changed while a guest is checked in'
      using errcode = '55000';
  end if;
  return new;
end;
$function$;

drop trigger if exists guard_hotel_room_checked_in_status on public.hotel_rooms;
create trigger guard_hotel_room_checked_in_status
before update of room_status on public.hotel_rooms
for each row execute function private.guard_hotel_room_checked_in_status();
