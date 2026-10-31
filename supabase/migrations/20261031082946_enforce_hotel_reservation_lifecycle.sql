create or replace function private.guard_hotel_reservation_status_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.status is not distinct from new.status then return new; end if;

  if old.status = 'booked' and new.status in ('checked_in','cancelled') then
    if new.status = 'checked_in' then
      update public.hotel_rooms set room_status = 'occupied', updated_at = now()
      where id = new.room_id and shop_id = new.shop_id and room_status = 'available';
      if not found then
        raise exception 'Room is not available for check-in' using errcode = '55000';
      end if;
    end if;
    return new;
  end if;

  if old.status = 'checked_in' and new.status = 'checked_out' then
    update public.hotel_rooms
    set room_status = case when room_status = 'occupied' then 'available' else room_status end,
        updated_at = now()
    where id = new.room_id and shop_id = new.shop_id;
    if not found then
      raise exception 'Reservation room no longer exists' using errcode = '23503';
    end if;
    return new;
  end if;

  raise exception 'Invalid hotel reservation status transition: % -> %', old.status, new.status
    using errcode = '23514';
end;
$$;

drop trigger if exists guard_hotel_reservation_status_transition on public.hotel_reservations;
create trigger guard_hotel_reservation_status_transition before update of status
on public.hotel_reservations for each row execute function private.guard_hotel_reservation_status_transition();
