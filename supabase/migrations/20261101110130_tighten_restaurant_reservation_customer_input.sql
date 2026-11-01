revoke insert (duration_minutes, status) on public.restaurant_reservations from anon, authenticated;
alter table public.restaurant_reservations drop constraint if exists restaurant_reservations_customer_phone_check;
alter table public.restaurant_reservations add constraint restaurant_reservations_customer_phone_format_check
 check(customer_phone ~ '^[0-9+() -]{7,20}$' and char_length(regexp_replace(customer_phone,'[^0-9]','','g')) between 7 and 15);
create or replace function private.guard_restaurant_reservation_update()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_capacity smallint;
begin
 if new.shop_id is distinct from old.shop_id or new.customer_id is distinct from old.customer_id
 or new.customer_name is distinct from old.customer_name or new.customer_phone is distinct from old.customer_phone
 or new.party_size is distinct from old.party_size or new.reservation_at is distinct from old.reservation_at
 or new.duration_minutes is distinct from old.duration_minutes or new.customer_notes is distinct from old.customer_notes then
  raise exception 'Customer reservation details cannot be edited by the shop';
 end if;
 if old.status='pending' and new.status not in('pending','confirmed','cancelled') then raise exception 'A pending reservation can only be confirmed or cancelled';
 elsif old.status='confirmed' and new.status not in('confirmed','completed','cancelled','no_show') then raise exception 'Invalid confirmed-reservation status transition';
 elsif old.status in('cancelled','completed','no_show') and new.status is distinct from old.status then raise exception 'A closed reservation cannot be reopened';
 end if;
 if new.status='confirmed' and new.reservation_at<=pg_catalog.now() then raise exception 'A past reservation cannot be confirmed'; end if;
 if new.status='confirmed' and new.table_id is null then raise exception 'Assign a restaurant table before confirming this reservation'; end if;
 if new.table_id is not null and (new.status='confirmed' or new.table_id is distinct from old.table_id) then
  select t.capacity into v_capacity from public.restaurant_tables t where t.id=new.table_id and t.shop_id=new.shop_id and t.is_enabled=true and t.table_status<>'maintenance';
  if not found then raise exception 'Choose an enabled table in this restaurant'; end if;
  if v_capacity<new.party_size then raise exception 'Selected table does not have enough seats'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.table_id::text,0));
  if exists(select 1 from public.restaurant_reservations r where r.shop_id=new.shop_id and r.table_id=new.table_id and r.id<>new.id and r.status='confirmed'
   and r.reservation_at<new.reservation_at+(new.duration_minutes*interval '1 minute')
   and r.reservation_at+(r.duration_minutes*interval '1 minute')>new.reservation_at) then
   raise exception 'This table already has an overlapping confirmed reservation';
  end if;
 end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;