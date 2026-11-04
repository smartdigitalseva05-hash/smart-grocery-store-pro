
create table if not exists public.shop_advanced_records (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  record_type text not null check (record_type in (
    'quotation','invoice','sales_return','purchase_return','delivery',
    'appointment','customer_follow_up','loyalty_entry','warranty_claim',
    'stock_adjustment','service_job','task'
  )),
  reference_no text,
  title text not null check (char_length(btrim(title)) between 1 and 180),
  customer_name text,
  customer_phone text,
  amount numeric(12,2) not null default 0 check (amount >= 0),
  due_date date,
  status text not null default 'open' check (status in (
    'draft','open','pending','in_progress','completed','cancelled','paid','returned'
  )),
  details jsonb not null default '{}'::jsonb,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shop_advanced_records_shop_type_date_idx
  on public.shop_advanced_records(shop_id, record_type, created_at desc);
create index if not exists shop_advanced_records_shop_status_due_idx
  on public.shop_advanced_records(shop_id, status, due_date);
alter table public.shop_advanced_records enable row level security;
revoke all on public.shop_advanced_records from anon, public;
grant select, insert, update, delete on public.shop_advanced_records to authenticated;
drop policy if exists "shop advanced records select owner" on public.shop_advanced_records;
drop policy if exists "shop advanced records insert owner" on public.shop_advanced_records;
drop policy if exists "shop advanced records update owner" on public.shop_advanced_records;
drop policy if exists "shop advanced records delete owner" on public.shop_advanced_records;
create policy "shop advanced records select owner"
on public.shop_advanced_records for select to authenticated
using (private.is_shop_owner(shop_id));
create policy "shop advanced records insert owner"
on public.shop_advanced_records for insert to authenticated
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id) and created_by = (select auth.uid()));
create policy "shop advanced records update owner"
on public.shop_advanced_records for update to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
create policy "shop advanced records delete owner"
on public.shop_advanced_records for delete to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
