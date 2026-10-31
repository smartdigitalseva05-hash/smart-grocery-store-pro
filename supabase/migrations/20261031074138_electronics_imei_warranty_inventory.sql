create table if not exists public.electronics_inventory (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 device_name text not null check(char_length(btrim(device_name)) between 1 and 120), brand text, model text,
 imei_1 text, imei_2 text, serial_number text, purchase_date date, warranty_start date, warranty_end date,
 supplier text, purchase_price numeric(12,2) check(purchase_price is null or purchase_price>=0),
 sale_price numeric(12,2) check(sale_price is null or sale_price>=0),
 device_status text not null default 'in_stock' check(device_status in ('in_stock','sold','returned','under_service','written_off')),
 customer_name text, customer_phone text, sold_at timestamptz, notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(warranty_start is null or warranty_end is null or warranty_end>=warranty_start),
 unique(shop_id,imei_1),unique(shop_id,imei_2),unique(shop_id,serial_number)
);
create index if not exists electronics_inventory_shop_status_idx on public.electronics_inventory(shop_id,device_status,created_at desc);
create index if not exists electronics_inventory_warranty_idx on public.electronics_inventory(shop_id,warranty_end);
alter table public.electronics_inventory enable row level security;
grant select,insert,update,delete on public.electronics_inventory to authenticated;
drop policy if exists electronics_inventory_read on public.electronics_inventory;
create policy electronics_inventory_read on public.electronics_inventory for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists electronics_inventory_insert on public.electronics_inventory;
create policy electronics_inventory_insert on public.electronics_inventory for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=electronics_inventory.shop_id and s.business_type='electronics' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (product_id is null or exists(select 1 from public.products p where p.id=electronics_inventory.product_id and p.shop_id=electronics_inventory.shop_id)));
drop policy if exists electronics_inventory_update on public.electronics_inventory;
create policy electronics_inventory_update on public.electronics_inventory for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=electronics_inventory.shop_id and s.business_type='electronics' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=electronics_inventory.shop_id and s.business_type='electronics' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (product_id is null or exists(select 1 from public.products p where p.id=electronics_inventory.product_id and p.shop_id=electronics_inventory.shop_id)));
drop policy if exists electronics_inventory_delete on public.electronics_inventory;
create policy electronics_inventory_delete on public.electronics_inventory for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=electronics_inventory.shop_id and s.business_type='electronics' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
