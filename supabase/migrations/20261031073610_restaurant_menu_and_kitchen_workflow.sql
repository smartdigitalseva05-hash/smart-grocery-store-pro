create table if not exists public.restaurant_menu_items (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 name text not null check(char_length(btrim(name)) between 1 and 120),
 category text not null default 'Main Course' check(char_length(btrim(category)) between 1 and 60),
 description text, price numeric(12,2) not null check(price>=0),
 prep_time_minutes integer not null default 15 check(prep_time_minutes between 0 and 1440),
 is_available boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists restaurant_menu_items_shop_idx on public.restaurant_menu_items(shop_id,is_available,category);
create table if not exists public.restaurant_kitchen_tickets (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 ticket_number bigint generated always as identity, table_id uuid references public.restaurant_tables(id) on delete set null,
 guest_name text, guest_count integer not null default 1 check(guest_count between 1 and 100),
 status text not null default 'new' check(status in ('new','preparing','ready','served','cancelled')),
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(shop_id,ticket_number)
);
create index if not exists restaurant_kitchen_tickets_shop_status_idx on public.restaurant_kitchen_tickets(shop_id,status,created_at desc);
create table if not exists public.restaurant_kitchen_ticket_items (
 id uuid primary key default gen_random_uuid(), ticket_id uuid not null references public.restaurant_kitchen_tickets(id) on delete cascade,
 menu_item_id uuid references public.restaurant_menu_items(id) on delete set null,
 item_name text not null check(char_length(btrim(item_name)) between 1 and 120),
 quantity integer not null check(quantity between 1 and 500), unit_price numeric(12,2) not null check(unit_price>=0),
 item_notes text, created_at timestamptz not null default now()
);
create index if not exists restaurant_kitchen_ticket_items_ticket_idx on public.restaurant_kitchen_ticket_items(ticket_id);
alter table public.restaurant_menu_items enable row level security;
alter table public.restaurant_kitchen_tickets enable row level security;
alter table public.restaurant_kitchen_ticket_items enable row level security;
grant select on public.restaurant_menu_items to anon,authenticated;
grant insert,update,delete on public.restaurant_menu_items to authenticated;
grant select,insert,update,delete on public.restaurant_kitchen_tickets to authenticated;
grant select,insert,update,delete on public.restaurant_kitchen_ticket_items to authenticated;
drop policy if exists restaurant_menu_items_read on public.restaurant_menu_items;
create policy restaurant_menu_items_read on public.restaurant_menu_items for select to anon,authenticated
using(private.is_shop_owner(shop_id) or private.is_super_admin() or (is_available=true and private.is_public_shop_active(shop_id)));
drop policy if exists restaurant_menu_items_insert on public.restaurant_menu_items;
create policy restaurant_menu_items_insert on public.restaurant_menu_items for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_menu_items.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_menu_items_update on public.restaurant_menu_items;
create policy restaurant_menu_items_update on public.restaurant_menu_items for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_menu_items.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_menu_items.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_menu_items_delete on public.restaurant_menu_items;
create policy restaurant_menu_items_delete on public.restaurant_menu_items for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_menu_items.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_kitchen_tickets_read on public.restaurant_kitchen_tickets;
create policy restaurant_kitchen_tickets_read on public.restaurant_kitchen_tickets for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists restaurant_kitchen_tickets_insert on public.restaurant_kitchen_tickets;
create policy restaurant_kitchen_tickets_insert on public.restaurant_kitchen_tickets for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_kitchen_tickets.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (table_id is null or exists(select 1 from public.restaurant_tables t where t.id=restaurant_kitchen_tickets.table_id and t.shop_id=restaurant_kitchen_tickets.shop_id)));
drop policy if exists restaurant_kitchen_tickets_update on public.restaurant_kitchen_tickets;
create policy restaurant_kitchen_tickets_update on public.restaurant_kitchen_tickets for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_kitchen_tickets.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_kitchen_tickets.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (table_id is null or exists(select 1 from public.restaurant_tables t where t.id=restaurant_kitchen_tickets.table_id and t.shop_id=restaurant_kitchen_tickets.shop_id)));
drop policy if exists restaurant_kitchen_tickets_delete on public.restaurant_kitchen_tickets;
create policy restaurant_kitchen_tickets_delete on public.restaurant_kitchen_tickets for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_kitchen_tickets.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_kitchen_ticket_items_read on public.restaurant_kitchen_ticket_items;
create policy restaurant_kitchen_ticket_items_read on public.restaurant_kitchen_ticket_items for select to authenticated
using(exists(select 1 from public.restaurant_kitchen_tickets t where t.id=restaurant_kitchen_ticket_items.ticket_id and (private.is_shop_owner(t.shop_id) or private.is_super_admin())));
drop policy if exists restaurant_kitchen_ticket_items_insert on public.restaurant_kitchen_ticket_items;
create policy restaurant_kitchen_ticket_items_insert on public.restaurant_kitchen_ticket_items for insert to authenticated
with check(exists(select 1 from public.restaurant_kitchen_tickets t join public.shops s on s.id=t.shop_id where t.id=restaurant_kitchen_ticket_items.ticket_id and private.is_shop_owner(t.shop_id) and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (menu_item_id is null or exists(select 1 from public.restaurant_menu_items m join public.restaurant_kitchen_tickets t on t.shop_id=m.shop_id where t.id=restaurant_kitchen_ticket_items.ticket_id and m.id=restaurant_kitchen_ticket_items.menu_item_id)));
drop policy if exists restaurant_kitchen_ticket_items_update on public.restaurant_kitchen_ticket_items;
create policy restaurant_kitchen_ticket_items_update on public.restaurant_kitchen_ticket_items for update to authenticated
using(exists(select 1 from public.restaurant_kitchen_tickets t where t.id=restaurant_kitchen_ticket_items.ticket_id and private.is_shop_owner(t.shop_id)))
with check(exists(select 1 from public.restaurant_kitchen_tickets t join public.shops s on s.id=t.shop_id where t.id=restaurant_kitchen_ticket_items.ticket_id and private.is_shop_owner(t.shop_id) and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (menu_item_id is null or exists(select 1 from public.restaurant_menu_items m join public.restaurant_kitchen_tickets t on t.shop_id=m.shop_id where t.id=restaurant_kitchen_ticket_items.ticket_id and m.id=restaurant_kitchen_ticket_items.menu_item_id)));
drop policy if exists restaurant_kitchen_ticket_items_delete on public.restaurant_kitchen_ticket_items;
create policy restaurant_kitchen_ticket_items_delete on public.restaurant_kitchen_ticket_items for delete to authenticated
using(exists(select 1 from public.restaurant_kitchen_tickets t join public.shops s on s.id=t.shop_id where t.id=restaurant_kitchen_ticket_items.ticket_id and private.is_shop_owner(t.shop_id) and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
