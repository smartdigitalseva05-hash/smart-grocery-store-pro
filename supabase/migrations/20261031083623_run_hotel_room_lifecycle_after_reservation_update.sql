drop trigger if exists guard_hotel_reservation_status_transition on public.hotel_reservations;
create trigger guard_hotel_reservation_status_transition
after update of status on public.hotel_reservations
for each row execute function private.guard_hotel_reservation_status_transition();
