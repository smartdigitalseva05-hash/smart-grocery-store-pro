create unique index if not exists grocery_suppliers_shop_id_id_uidx
  on public.grocery_suppliers (shop_id, id);

create table if not exists public.grocery_supplier_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  supplier_id uuid not null,
  amount numeric(12,2) not null check (amount > 0 and amount <= 100000000),
  payment_date date not null default current_date,
  payment_method text not null default 'cash'
    check (payment_method in ('cash','upi','bank','cheque','other')),
  reference_number text,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  constraint grocery_supplier_payments_supplier_shop_fkey
    foreign key (shop_id, supplier_id)
    references public.grocery_suppliers(shop_id, id) on delete restrict
);

create index if not exists grocery_supplier_payments_shop_supplier_date_idx
  on public.grocery_supplier_payments(shop_id, supplier_id, payment_date desc, created_at desc);

alter table public.grocery_supplier_payments enable row level security;

create policy grocery_supplier_payments_read
  on public.grocery_supplier_payments for select to authenticated
  using (private.is_shop_owner(shop_id) or private.is_super_admin());

create policy grocery_supplier_payments_insert
  on public.grocery_supplier_payments for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and private.is_shop_owner(shop_id)
    and exists (
      select 1 from public.shops s
      where s.id = grocery_supplier_payments.shop_id
        and s.business_type = 'grocery'
        and s.is_active = true
        and s.status = 'active'
        and s.subscription_expires_at > now()
    )
  );

revoke all on public.grocery_supplier_payments from anon;
grant select, insert on public.grocery_supplier_payments to authenticated;
