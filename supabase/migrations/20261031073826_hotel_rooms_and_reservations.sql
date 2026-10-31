create table if not exists public.hotel_rooms (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 room_number text not null check(char_length(btrim(room_number)) between 1 and 30),
 room_type text not null default 'Standard' check(char_length(btrim(room_type)) between 1 and 60),
 floor_label text, capacity integer not null default 2 check(capacity between 1 and 20),
 base_rate numeric(12,2) not null check(base_rate>=0),
 room_status text not null default 'available' check(room_status in ('available','occupied','maintenance','blocked')),
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(shop_id,room_number)
);
create index if not exists hotel_rooms_shop_status_idx on public.hotel_rooms(shop_id,room_status,is_active);
create table if not exists public.hotel_reservations (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 room_id uuid not null references public.hotel_rooms(id) on delete restrict,
 booking_number bigint generated always as identity,
 guest_name text not null check(char_length(btrim(guest_name)) between 1 and 120),
 guest_phone text, guest_count integer not null default 1 check(guest_count between 1 and 20),
 check_in date not null, check_out date not null,
 status text not null default 'booked' check(status in ('booked','checked_in','checked_out','cancelled')),
 nightly_rate numeric(12,2) not null check(nightly_rate>=0), notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(check_out>check_in), unique(shop_id,booking_number)
);
create index if not exists hotel_reservations_shop_dates_idx on public.hotel_reservations(shop_id,check_in,check_out,status);
create index if not exists hotel_reservations_room_dates_idx on public.hotel_reservations(room_id,check_in,check_out,status);
create or replace function private.prevent_hotel_room_double_booking()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.room_id::text,0));
 if new.status in ('booked','checked_in') and exists(select 1 from public.hotel_reservations r where r.room_id=new.room_id and r.shop_id=new.shop_id and r.status in ('booked','checked_in') and r.id is distinct from new.id and daterange(r.check_in,r.check_out,'[)') && daterange(new.check_in,new.check_out,'[)')) then
  raise exception 'This room already has an overlapping active reservation' using errcode='23P01';
 end if;
 return new;
end;
$$;
drop trigger if exists hotel_reservation_no_overlap on public.hotel_reservations;
create trigger hotel_reservation_no_overlap before insert or update of room_id,shop_id,check_in,check_out,status on public.hotel_reservations for each row execute function private.prevent_hotel_room_double_booking();
alter table public.hotel_rooms enable row level security;
alter table public.hotel_reservations enable row level security;
grant select on public.hotel_rooms to anon,authenticated;
grant insert,update,delete on public.hotel_rooms to authenticated;
grant select,insert,update,delete on public.hotel_reservations to authenticated;
drop policy if exists hotel_rooms_read on public.hotel_rooms;
create policy hotel_rooms_read on public.hotel_rooms for select to anon,authenticated
using(private.is_shop_owner(shop_id) or private.is_super_admin() or (is_active=true and private.is_public_shop_active(shop_id)));
drop policy if exists hotel_rooms_insert on public.hotel_rooms;
create policy hotel_rooms_insert on public.hotel_rooms for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_rooms.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists hotel_rooms_update on public.hotel_rooms;
create policy hotel_rooms_update on public.hotel_rooms for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_rooms.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_rooms.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists hotel_rooms_delete on public.hotel_rooms;
create policy hotel_rooms_delete on public.hotel_rooms for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_rooms.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists hotel_reservations_read on public.hotel_reservations;
create policy hotel_reservations_read on public.hotel_reservations for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists hotel_reservations_insert on public.hotel_reservations;
create policy hotel_reservations_insert on public.hotel_reservations for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_reservations.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.hotel_rooms r where r.id=hotel_reservations.room_id and r.shop_id=hotel_reservations.shop_id and r.is_active=true));
drop policy if exists hotel_reservations_update on public.hotel_reservations;
create policy hotel_reservations_update on public.hotel_reservations for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_reservations.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_reservations.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.hotel_rooms r where r.id=hotel_reservations.room_id and r.shop_id=hotel_reservations.shop_id));
drop policy if exists hotel_reservations_delete on public.hotel_reservations;
create policy hotel_reservations_delete on public.hotel_reservations for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=hotel_reservations.shop_id and s.business_type='hotel' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
