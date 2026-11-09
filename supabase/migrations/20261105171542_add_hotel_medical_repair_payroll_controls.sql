
-- Additive operational controls for Hotel, Medical, Repair and Office modules.
-- Existing records and tables are preserved.

create table if not exists public.hotel_payment_records (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  booking_request_id uuid references public.hotel_booking_requests(id) on delete set null,
  reservation_id uuid references public.hotel_reservations(id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'INR' check (currency = 'INR'),
  payment_status text not null default 'pending'
    check (payment_status in ('pending','verified','failed','refunded','partially_refunded')),
  gateway text not null default 'razorpay' check (gateway = 'razorpay'),
  gateway_order_id text unique,
  gateway_payment_id text unique,
  verified_at timestamptz,
  refund_amount numeric(12,2) not null default 0 check (refund_amount >= 0 and refund_amount <= amount),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hotel_payment_has_booking check (booking_request_id is not null or reservation_id is not null),
  constraint hotel_payment_verified_requires_reference check (payment_status <> 'verified' or (gateway_payment_id is not null and verified_at is not null))
);
create index if not exists hotel_payment_records_shop_created_idx
  on public.hotel_payment_records(shop_id, created_at desc);
alter table public.hotel_payment_records enable row level security;
drop policy if exists hotel_payment_records_owner_read on public.hotel_payment_records;
create policy hotel_payment_records_owner_read on public.hotel_payment_records
  for select to authenticated
  using (private.is_shop_owner(shop_id) or private.is_super_admin());
-- No anon/authenticated INSERT or UPDATE: payment rows must be written by a verified server-side gateway flow.

create table if not exists public.repair_warranty_records (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  service_job_id uuid not null references public.electronics_service_jobs(id) on delete cascade,
  warranty_number text not null,
  issued_at date not null default current_date,
  starts_on date not null default current_date,
  expires_on date not null,
  coverage_description text not null,
  terms text,
  status text not null default 'active' check (status in ('active','expired','claimed','void')),
  claim_notes text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint repair_warranty_dates_valid check (expires_on >= starts_on),
  constraint repair_warranty_shop_number_unique unique(shop_id,warranty_number),
  constraint repair_warranty_job_unique unique(service_job_id)
);
create index if not exists repair_warranty_shop_expiry_idx
  on public.repair_warranty_records(shop_id, expires_on);
alter table public.repair_warranty_records enable row level security;
drop policy if exists repair_warranty_owner_read on public.repair_warranty_records;
create policy repair_warranty_owner_read on public.repair_warranty_records
  for select to authenticated
  using (private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists repair_warranty_owner_insert on public.repair_warranty_records;
create policy repair_warranty_owner_insert on public.repair_warranty_records
  for insert to authenticated
  with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));
drop policy if exists repair_warranty_owner_update on public.repair_warranty_records;
create policy repair_warranty_owner_update on public.repair_warranty_records
  for update to authenticated
  using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
  with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

create table if not exists public.medical_batch_compliance_checks (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  batch_id uuid not null references public.medical_inventory_batches(id) on delete cascade,
  check_type text not null check (check_type in ('license_review','prescription_review','cold_chain','storage_condition','recall_check','expiry_review','other')),
  result text not null check (result in ('pass','fail','action_required','not_applicable')),
  checked_at timestamptz not null default now(),
  checked_by uuid references auth.users(id) on delete set null,
  notes text,
  evidence_reference text,
  created_at timestamptz not null default now()
);
create index if not exists medical_compliance_shop_batch_date_idx
  on public.medical_batch_compliance_checks(shop_id,batch_id,checked_at desc);
alter table public.medical_batch_compliance_checks enable row level security;
drop policy if exists medical_compliance_owner_read on public.medical_batch_compliance_checks;
create policy medical_compliance_owner_read on public.medical_batch_compliance_checks
  for select to authenticated
  using (private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists medical_compliance_owner_insert on public.medical_batch_compliance_checks;
create policy medical_compliance_owner_insert on public.medical_batch_compliance_checks
  for insert to authenticated
  with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id) and (checked_by is null or checked_by = (select auth.uid())));
drop policy if exists medical_compliance_owner_update on public.medical_batch_compliance_checks;
create policy medical_compliance_owner_update on public.medical_batch_compliance_checks
  for update to authenticated
  using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
  with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

alter table public.medical_inventory_batches
  add column if not exists cold_chain_required boolean not null default false,
  add column if not exists storage_instructions text,
  add column if not exists recall_status text not null default 'clear'
    check (recall_status in ('clear','under_review','recalled','quarantined')),
  add column if not exists license_verification_reference text;
create index if not exists medical_batches_expiry_alert_idx
  on public.medical_inventory_batches(shop_id,expiry_date)
  where batch_status = 'active' and quantity > 0;

alter table public.office_payroll_records
  add column if not exists gross_amount numeric(12,2),
  add column if not exists total_deductions numeric(12,2) not null default 0,
  add column if not exists statutory_deductions jsonb not null default '{}'::jsonb,
  add column if not exists employer_contributions jsonb not null default '{}'::jsonb,
  add column if not exists payroll_rule_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists calculation_version text not null default 'manual-v1';

