create table if not exists public.medical_inventory_batches (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 medicine_name text not null check(char_length(btrim(medicine_name)) between 1 and 120), brand text,
 batch_number text not null check(char_length(btrim(batch_number)) between 1 and 80),
 manufactured_on date, expiry_date date not null, quantity integer not null default 0 check(quantity>=0),
 purchase_price numeric(12,2) check(purchase_price is null or purchase_price>=0),
 mrp numeric(12,2) check(mrp is null or mrp>=0), supplier text, storage_location text,
 prescription_required boolean not null default false,
 batch_status text not null default 'active' check(batch_status in ('active','quarantined','returned','disposed')),
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(shop_id,batch_number),check(manufactured_on is null or expiry_date>=manufactured_on)
);
create index if not exists medical_batches_shop_expiry_idx on public.medical_inventory_batches(shop_id,expiry_date,quantity);
create index if not exists medical_batches_shop_name_idx on public.medical_inventory_batches(shop_id,medicine_name);
alter table public.medical_inventory_batches enable row level security;
grant select,insert,update,delete on public.medical_inventory_batches to authenticated;
drop policy if exists medical_inventory_batches_read on public.medical_inventory_batches;
create policy medical_inventory_batches_read on public.medical_inventory_batches for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists medical_inventory_batches_insert on public.medical_inventory_batches;
create policy medical_inventory_batches_insert on public.medical_inventory_batches for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=medical_inventory_batches.shop_id and s.business_type='medical' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (product_id is null or exists(select 1 from public.products p where p.id=medical_inventory_batches.product_id and p.shop_id=medical_inventory_batches.shop_id)));
drop policy if exists medical_inventory_batches_update on public.medical_inventory_batches;
create policy medical_inventory_batches_update on public.medical_inventory_batches for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=medical_inventory_batches.shop_id and s.business_type='medical' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=medical_inventory_batches.shop_id and s.business_type='medical' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and (product_id is null or exists(select 1 from public.products p where p.id=medical_inventory_batches.product_id and p.shop_id=medical_inventory_batches.shop_id)));
drop policy if exists medical_inventory_batches_delete on public.medical_inventory_batches;
create policy medical_inventory_batches_delete on public.medical_inventory_batches for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=medical_inventory_batches.shop_id and s.business_type='medical' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
