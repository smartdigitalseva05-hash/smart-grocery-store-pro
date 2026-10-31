create or replace function private.guard_hotel_room_status_during_checkin()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.room_status is distinct from old.room_status
     and exists (
       select 1
       from public.hotel_reservations r
       where r.room_id = new.id
         and r.shop_id = new.shop_id
         and r.status = 'checked_in'
     )
     and new.room_status <> 'occupied' then
    raise exception 'A room with a checked-in guest must remain occupied until checkout'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_hotel_room_status_during_checkin on public.hotel_rooms;
create trigger guard_hotel_room_status_during_checkin
before update of room_status on public.hotel_rooms
for each row execute function private.guard_hotel_room_status_during_checkin();
