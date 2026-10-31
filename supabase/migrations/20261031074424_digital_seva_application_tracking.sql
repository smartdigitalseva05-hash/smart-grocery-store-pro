create table if not exists public.digital_service_applications (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 application_number bigint generated always as identity,
 service_name text not null check(char_length(btrim(service_name)) between 1 and 120),
 applicant_name text not null check(char_length(btrim(applicant_name)) between 1 and 120),
 applicant_phone text not null check(char_length(btrim(applicant_phone)) between 5 and 30),
 reference_number text, applied_on date not null default current_date, expected_date date,
 application_status text not null default 'submitted' check(application_status in ('submitted','under_review','approved','rejected','completed','cancelled')),
 document_checklist text, service_fee numeric(12,2) not null default 0 check(service_fee>=0),
 amount_paid numeric(12,2) not null default 0 check(amount_paid>=0), receipt_number text, notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(shop_id,application_number),check(expected_date is null or expected_date>=applied_on)
);
create index if not exists digital_service_apps_shop_status_idx on public.digital_service_applications(shop_id,application_status,applied_on desc);
create index if not exists digital_service_apps_shop_phone_idx on public.digital_service_applications(shop_id,applicant_phone);
alter table public.digital_service_applications enable row level security;
grant select,insert,update,delete on public.digital_service_applications to authenticated;
drop policy if exists digital_service_applications_read on public.digital_service_applications;
create policy digital_service_applications_read on public.digital_service_applications for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists digital_service_applications_insert on public.digital_service_applications;
create policy digital_service_applications_insert on public.digital_service_applications for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=digital_service_applications.shop_id and s.business_type='digital_services' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and amount_paid<=service_fee);
drop policy if exists digital_service_applications_update on public.digital_service_applications;
create policy digital_service_applications_update on public.digital_service_applications for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=digital_service_applications.shop_id and s.business_type='digital_services' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=digital_service_applications.shop_id and s.business_type='digital_services' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and amount_paid<=service_fee);
drop policy if exists digital_service_applications_delete on public.digital_service_applications;
create policy digital_service_applications_delete on public.digital_service_applications for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=digital_service_applications.shop_id and s.business_type='digital_services' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
