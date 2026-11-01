create table if not exists public.hotel_booking_requests (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,
 customer_id uuid references auth.users(id) on delete set null,
 requested_room_type text not null check(char_length(btrim(requested_room_type)) between 1 and 80),
 guest_name text not null check(char_length(btrim(guest_name)) between 1 and 120),
 guest_phone text not null check(guest_phone ~ '^[0-9+() -]{7,20}$' and char_length(regexp_replace(guest_phone,'[^0-9]','','g')) between 7 and 15),
 guest_count integer not null check(guest_count between 1 and 20),check_in date not null,check_out date not null,
 notes text check(notes is null or char_length(notes)<=500),
 status text not null default 'pending' check(status in('pending','accepted','rejected','cancelled')),
 reservation_id uuid references public.hotel_reservations(id) on delete restrict,
 shopkeeper_notes text check(shopkeeper_notes is null or char_length(shopkeeper_notes)<=500),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint hotel_booking_requests_dates_check check(check_out>check_in)
);
create index if not exists hotel_booking_requests_shop_created_idx on public.hotel_booking_requests(shop_id,created_at desc);
create index if not exists hotel_booking_requests_shop_status_dates_idx on public.hotel_booking_requests(shop_id,status,check_in);
create index if not exists hotel_booking_requests_customer_id_idx on public.hotel_booking_requests(customer_id);
alter table public.hotel_booking_requests enable row level security;
revoke all on public.hotel_booking_requests from anon,authenticated;
grant insert(id,shop_id,customer_id,requested_room_type,guest_name,guest_phone,guest_count,check_in,check_out,notes) on public.hotel_booking_requests to anon,authenticated;
grant select(id,shop_id,customer_id,requested_room_type,guest_name,guest_phone,guest_count,check_in,check_out,notes,status,reservation_id,shopkeeper_notes,created_at,updated_at) on public.hotel_booking_requests to authenticated;
grant update(status,reservation_id,shopkeeper_notes) on public.hotel_booking_requests to authenticated;
create or replace function private.is_active_hotel_booking_shop(p_shop_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.shops s join public.profiles p on p.id=s.owner_id where s.id=p_shop_id and s.business_type='hotel' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>pg_catalog.now() and p.role='shopkeeper'::public.user_role and p.is_active=true);
$$;
revoke all on function private.is_active_hotel_booking_shop(uuid) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.is_active_hotel_booking_shop(uuid) to anon,authenticated;
drop policy if exists hotel_booking_requests_public_insert on public.hotel_booking_requests;
create policy hotel_booking_requests_public_insert on public.hotel_booking_requests for insert to anon,authenticated with check(status='pending' and reservation_id is null and customer_id is not distinct from (select auth.uid()) and check_in>=current_date and check_out>check_in and check_out<=current_date+90 and private.is_active_hotel_booking_shop(shop_id));
drop policy if exists hotel_booking_requests_owner_read on public.hotel_booking_requests;
create policy hotel_booking_requests_owner_read on public.hotel_booking_requests for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists hotel_booking_requests_owner_update on public.hotel_booking_requests;
create policy hotel_booking_requests_owner_update on public.hotel_booking_requests for update to authenticated using((select private.is_shop_owner(shop_id)) and (select private.is_active_hotel_booking_shop(shop_id))) with check((select private.is_shop_owner(shop_id)) and (select private.is_active_hotel_booking_shop(shop_id)));
create or replace function private.guard_hotel_booking_request_update() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_reservation public.hotel_reservations%rowtype;
begin
 if new.shop_id is distinct from old.shop_id or new.customer_id is distinct from old.customer_id or new.requested_room_type is distinct from old.requested_room_type or new.guest_name is distinct from old.guest_name or new.guest_phone is distinct from old.guest_phone or new.guest_count is distinct from old.guest_count or new.check_in is distinct from old.check_in or new.check_out is distinct from old.check_out or new.notes is distinct from old.notes then raise exception 'Guest booking request details cannot be edited by the hotel'; end if;
 if old.status='pending' and new.status not in('pending','accepted','rejected','cancelled') then raise exception 'Invalid pending booking request transition'; elsif old.status in('accepted','rejected','cancelled') and new.status is distinct from old.status then raise exception 'A closed booking request cannot be reopened'; end if;
 if new.status='accepted' then
  if new.reservation_id is null then raise exception 'An accepted request must link to a hotel reservation'; end if;
  select * into v_reservation from public.hotel_reservations r where r.id=new.reservation_id and r.shop_id=new.shop_id and r.guest_name=new.guest_name and r.guest_count=new.guest_count and r.check_in=new.check_in and r.check_out=new.check_out;
  if not found then raise exception 'Linked hotel reservation does not match this guest request'; end if;
 elsif new.reservation_id is not null then raise exception 'Only an accepted request may link a hotel reservation'; end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_hotel_booking_request_update() from public,anon,authenticated;
drop trigger if exists hotel_booking_requests_guard_update on public.hotel_booking_requests;
create trigger hotel_booking_requests_guard_update before update on public.hotel_booking_requests for each row execute function private.guard_hotel_booking_request_update();
create or replace function private.hotel_confirm_booking_request(p_request_id uuid,p_room_id uuid,p_nightly_rate numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_request public.hotel_booking_requests%rowtype;v_room public.hotel_rooms%rowtype;v_booking_id uuid;v_booking_number bigint;
begin
 if auth.uid() is null then raise exception 'Sign in as the hotel shopkeeper first' using errcode='28000'; end if;
 select * into v_request from public.hotel_booking_requests where id=p_request_id for update;
 if not found then raise exception 'Booking request not found' using errcode='P0002'; end if;
 if not private.is_shop_owner(v_request.shop_id) and not private.is_super_admin() then raise exception 'You are not allowed to confirm this hotel booking request' using errcode='42501'; end if;
 if not private.is_active_hotel_booking_shop(v_request.shop_id) then raise exception 'The hotel shop must have an active subscription' using errcode='55000'; end if;
 if v_request.status<>'pending' then raise exception 'This booking request has already been processed' using errcode='55000'; end if;
 if p_nightly_rate is null or p_nightly_rate<0 or p_nightly_rate>100000000 then raise exception 'Enter a valid nightly room rate'; end if;
 select * into v_room from public.hotel_rooms where id=p_room_id and shop_id=v_request.shop_id and is_active=true and room_status not in('maintenance','blocked') and lower(btrim(room_type))=lower(btrim(v_request.requested_room_type));
 if not found then raise exception 'Select an active room of the requested type'; end if;
 if v_request.guest_count>v_room.capacity then raise exception 'Guest count exceeds this room capacity'; end if;
 insert into public.hotel_reservations(shop_id,room_id,guest_name,guest_phone,guest_count,check_in,check_out,nightly_rate,notes) values(v_request.shop_id,v_room.id,v_request.guest_name,v_request.guest_phone,v_request.guest_count,v_request.check_in,v_request.check_out,p_nightly_rate,v_request.notes) returning id,booking_number into v_booking_id,v_booking_number;
 update public.hotel_booking_requests set status='accepted',reservation_id=v_booking_id where id=v_request.id;
 return pg_catalog.jsonb_build_object('reservation_id',v_booking_id,'booking_number',v_booking_number);
end;$$;
revoke all on function private.hotel_confirm_booking_request(uuid,uuid,numeric) from public,anon;
grant execute on function private.hotel_confirm_booking_request(uuid,uuid,numeric) to authenticated;
create function public.hotel_confirm_booking_request(p_request_id uuid,p_room_id uuid,p_nightly_rate numeric) returns jsonb language sql security invoker set search_path='' as $$ select private.hotel_confirm_booking_request(p_request_id,p_room_id,p_nightly_rate); $$;
revoke all on function public.hotel_confirm_booking_request(uuid,uuid,numeric) from public,anon;
grant execute on function public.hotel_confirm_booking_request(uuid,uuid,numeric) to authenticated;
