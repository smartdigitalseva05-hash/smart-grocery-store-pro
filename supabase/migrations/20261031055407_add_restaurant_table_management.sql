create table if not exists public.restaurant_tables (
 id uuid primary key default gen_random_uuid(),
 shop_id uuid not null references public.shops(id) on delete cascade,
 table_code text not null check(length(btrim(table_code)) between 1 and 40),
 capacity smallint not null default 2 check(capacity between 1 and 100),
 table_status text not null default 'available' check(table_status in ('available','occupied','reserved','maintenance')),
 is_enabled boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint restaurant_table_shop_code_unique unique(shop_id,table_code)
);
create index if not exists restaurant_tables_shop_idx on public.restaurant_tables(shop_id);
alter table public.restaurant_tables enable row level security;
grant select on public.restaurant_tables to anon,authenticated;
grant insert,update,delete on public.restaurant_tables to authenticated;
drop policy if exists restaurant_tables_read on public.restaurant_tables;
create policy restaurant_tables_read on public.restaurant_tables for select to anon,authenticated
using(private.is_shop_owner(shop_id) or private.is_super_admin() or (is_enabled=true and private.is_public_shop_active(shop_id)));
drop policy if exists restaurant_tables_insert on public.restaurant_tables;
create policy restaurant_tables_insert on public.restaurant_tables for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_tables.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_tables_update on public.restaurant_tables;
create policy restaurant_tables_update on public.restaurant_tables for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_tables.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_tables.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists restaurant_tables_delete on public.restaurant_tables;
create policy restaurant_tables_delete on public.restaurant_tables for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=restaurant_tables.shop_id and s.business_type='restaurant' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
