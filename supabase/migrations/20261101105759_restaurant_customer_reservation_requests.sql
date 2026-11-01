create unique index if not exists restaurant_tables_shop_id_id_uidx on public.restaurant_tables(shop_id,id);
create table if not exists public.restaurant_reservations (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 table_id uuid, customer_id uuid references auth.users(id) on delete set null,
 customer_name text not null check(char_length(btrim(customer_name)) between 1 and 120),
 customer_phone text not null check(char_length(regexp_replace(customer_phone,'[^0-9]','','g')) between 7 and 15),
 party_size smallint not null check(party_size between 1 and 50), reservation_at timestamptz not null,
 duration_minutes smallint not null default 90 check(duration_minutes between 30 and 360),
 status text not null default 'pending' check(status in ('pending','confirmed','cancelled','completed','no_show')),
 customer_notes text check(customer_notes is null or char_length(customer_notes)<=500),
 shopkeeper_notes text check(shopkeeper_notes is null or char_length(shopkeeper_notes)<=500),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint restaurant_reservations_shop_table_fk foreign key(shop_id,table_id)
 references public.restaurant_tables(shop_id,id) on delete restrict
);
create index if not exists restaurant_reservations_shop_time_idx on public.restaurant_reservations(shop_id,reservation_at desc);
create index if not exists restaurant_reservations_shop_status_time_idx on public.restaurant_reservations(shop_id,status,reservation_at);
alter table public.restaurant_reservations enable row level security;
revoke all on public.restaurant_reservations from anon,authenticated;
grant insert(id,shop_id,customer_id,customer_name,customer_phone,party_size,reservation_at,duration_minutes,customer_notes,status) on public.restaurant_reservations to anon,authenticated;
grant select(id,shop_id,table_id,customer_id,customer_name,customer_phone,party_size,reservation_at,duration_minutes,status,customer_notes,shopkeeper_notes,created_at,updated_at) on public.restaurant_reservations to authenticated;
grant update(table_id,status,shopkeeper_notes) on public.restaurant_reservations to authenticated;
create or replace function private.is_active_restaurant_booking_shop(p_shop_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.shops s join public.profiles p on p.id=s.owner_id
 where s.id=p_shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active'::public.shop_status
 and s.subscription_expires_at>pg_catalog.now() and p.role='shopkeeper'::public.user_role and p.is_active=true);
$$;
revoke all on function private.is_active_restaurant_booking_shop(uuid) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.is_active_restaurant_booking_shop(uuid) to anon,authenticated;
drop policy if exists restaurant_reservations_public_insert on public.restaurant_reservations;
create policy restaurant_reservations_public_insert on public.restaurant_reservations for insert to anon,authenticated
with check(status='pending' and table_id is null and customer_id is not distinct from (select auth.uid())
and reservation_at>=pg_catalog.now()+interval '30 minutes' and reservation_at<=pg_catalog.now()+interval '90 days'
and private.is_active_restaurant_booking_shop(shop_id));
drop policy if exists restaurant_reservations_owner_read on public.restaurant_reservations;
create policy restaurant_reservations_owner_read on public.restaurant_reservations for select to authenticated
using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists restaurant_reservations_owner_update on public.restaurant_reservations;
create policy restaurant_reservations_owner_update on public.restaurant_reservations for update to authenticated
using((select private.is_shop_owner(shop_id)) and (select private.is_active_restaurant_booking_shop(shop_id)))
with check((select private.is_shop_owner(shop_id)) and (select private.is_active_restaurant_booking_shop(shop_id)));
create or replace function private.guard_restaurant_reservation_update() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_capacity smallint;
begin
 if new.shop_id is distinct from old.shop_id or new.customer_id is distinct from old.customer_id
 or new.customer_name is distinct from old.customer_name or new.customer_phone is distinct from old.customer_phone
 or new.party_size is distinct from old.party_size or new.reservation_at is distinct from old.reservation_at
 or new.duration_minutes is distinct from old.duration_minutes or new.customer_notes is distinct from old.customer_notes then
  raise exception 'Customer reservation details cannot be edited by the shop';
 end if;
 if old.status='pending' and new.status not in('pending','confirmed','cancelled') then
  raise exception 'A pending reservation can only be confirmed or cancelled';
 elsif old.status='confirmed' and new.status not in('confirmed','completed','cancelled','no_show') then
  raise exception 'Invalid confirmed-reservation status transition';
 elsif old.status in('cancelled','completed','no_show') and new.status is distinct from old.status then
  raise exception 'A closed reservation cannot be reopened';
 end if;
 if new.status='confirmed' and new.table_id is null then raise exception 'Assign a restaurant table before confirming this reservation'; end if;
 if new.table_id is not null then
  select t.capacity into v_capacity from public.restaurant_tables t
  where t.id=new.table_id and t.shop_id=new.shop_id and t.is_enabled=true and t.table_status<>'maintenance';
  if not found then raise exception 'Choose an enabled table in this restaurant'; end if;
  if v_capacity<new.party_size then raise exception 'Selected table does not have enough seats'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.table_id::text,0));
  if exists(select 1 from public.restaurant_reservations r where r.shop_id=new.shop_id and r.table_id=new.table_id
   and r.id<>new.id and r.status='confirmed'
   and r.reservation_at<new.reservation_at+(new.duration_minutes*interval '1 minute')
   and r.reservation_at+(r.duration_minutes*interval '1 minute')>new.reservation_at) then
   raise exception 'This table already has an overlapping confirmed reservation';
  end if;
 end if;
 new.updated_at:=pg_catalog.now();return new;
end;
$$;
revoke all on function private.guard_restaurant_reservation_update() from public,anon,authenticated;
drop trigger if exists restaurant_reservations_guard_update on public.restaurant_reservations;
create trigger restaurant_reservations_guard_update before update on public.restaurant_reservations
for each row execute function private.guard_restaurant_reservation_update();
