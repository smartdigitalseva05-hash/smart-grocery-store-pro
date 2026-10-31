create table if not exists public.office_employees (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 employee_code text, full_name text not null check(char_length(btrim(full_name)) between 1 and 120),
 phone text, designation text, employment_type text not null default 'full_time' check(employment_type in ('full_time','part_time','contract','intern')),
 joined_on date, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(shop_id,employee_code)
);
create index if not exists office_employees_shop_active_idx on public.office_employees(shop_id,is_active,full_name);
create table if not exists public.office_attendance (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 employee_id uuid not null references public.office_employees(id) on delete cascade,
 work_date date not null, attendance_status text not null default 'present' check(attendance_status in ('present','absent','half_day','leave')),
 check_in time, check_out time, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(employee_id,work_date), check(check_in is null or check_out is null or check_out>check_in)
);
create index if not exists office_attendance_shop_date_idx on public.office_attendance(shop_id,work_date desc,attendance_status);
alter table public.office_employees enable row level security;
alter table public.office_attendance enable row level security;
grant select,insert,update,delete on public.office_employees to authenticated;
grant select,insert,update,delete on public.office_attendance to authenticated;
drop policy if exists office_employees_read on public.office_employees;
create policy office_employees_read on public.office_employees for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists office_employees_insert on public.office_employees;
create policy office_employees_insert on public.office_employees for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_employees.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists office_employees_update on public.office_employees;
create policy office_employees_update on public.office_employees for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_employees.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_employees.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists office_employees_delete on public.office_employees;
create policy office_employees_delete on public.office_employees for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_employees.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
drop policy if exists office_attendance_read on public.office_attendance;
create policy office_attendance_read on public.office_attendance for select to authenticated using(private.is_shop_owner(shop_id) or private.is_super_admin());
drop policy if exists office_attendance_insert on public.office_attendance;
create policy office_attendance_insert on public.office_attendance for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_attendance.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.office_employees e where e.id=office_attendance.employee_id and e.shop_id=office_attendance.shop_id));
drop policy if exists office_attendance_update on public.office_attendance;
create policy office_attendance_update on public.office_attendance for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_attendance.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_attendance.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.office_employees e where e.id=office_attendance.employee_id and e.shop_id=office_attendance.shop_id));
drop policy if exists office_attendance_delete on public.office_attendance;
create policy office_attendance_delete on public.office_attendance for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=office_attendance.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
