
create table if not exists public.shop_business_ledger (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  business_type text not null check (business_type in ('grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other')),
  entry_type text not null check (entry_type in ('sale','purchase','expense','customer_payment','supplier_payment','sales_return','purchase_return','service_income','room_income','salary_payment','refund','other_income','other_expense')),
  entry_date date not null default current_date,
  reference_no text,
  party_name text,
  party_phone text,
  description text not null,
  quantity numeric(14,3),
  unit text,
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null check (total_amount >= 0),
  paid_amount numeric(14,2) not null default 0 check (paid_amount >= 0),
  payment_method text check (payment_method is null or payment_method in ('cash','upi','card','bank_transfer','credit','other')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','partial','paid','refunded')),
  metadata jsonb not null default '{}'::jsonb,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_business_ledger_paid_lte_total check (paid_amount <= total_amount + 0.01),
  constraint shop_business_ledger_metadata_object check (jsonb_typeof(metadata) = 'object')
);
alter table public.shop_business_ledger enable row level security;
revoke all on public.shop_business_ledger from anon;
grant select,insert,update,delete on public.shop_business_ledger to authenticated;
drop policy if exists shop_business_ledger_select_owner on public.shop_business_ledger;
create policy shop_business_ledger_select_owner on public.shop_business_ledger
for select to authenticated using (private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists shop_business_ledger_insert_owner on public.shop_business_ledger;
create policy shop_business_ledger_insert_owner on public.shop_business_ledger
for insert to authenticated with check (
  private.is_shop_owner(shop_id)
  and private.is_active_subscribed_shop(shop_id)
  and created_by = (select auth.uid())
  and exists (select 1 from public.shops s where s.id=shop_id and s.business_type=business_type)
);
drop policy if exists shop_business_ledger_update_owner on public.shop_business_ledger;
create policy shop_business_ledger_update_owner on public.shop_business_ledger
for update to authenticated using (
  private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id)
) with check (
  private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id)
  and created_by = (select auth.uid())
  and exists (select 1 from public.shops s where s.id=shop_id and s.business_type=business_type)
);
drop policy if exists shop_business_ledger_delete_owner on public.shop_business_ledger;
create policy shop_business_ledger_delete_owner on public.shop_business_ledger
for delete to authenticated using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
create index if not exists shop_business_ledger_shop_date_idx on public.shop_business_ledger(shop_id, entry_date desc, created_at desc);
create index if not exists shop_business_ledger_shop_type_idx on public.shop_business_ledger(shop_id, business_type, entry_type, entry_date desc);
create index if not exists shop_business_ledger_party_idx on public.shop_business_ledger(shop_id, party_name);
