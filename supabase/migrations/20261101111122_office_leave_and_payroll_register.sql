alter table public.office_employees add column if not exists monthly_salary numeric(12,2) not null default 0 check(monthly_salary>=0 and monthly_salary<=100000000);
grant select(monthly_salary) on public.office_employees to authenticated;
grant update(monthly_salary) on public.office_employees to authenticated;
create unique index if not exists office_employees_shop_id_id_uidx on public.office_employees(shop_id,id);
create table if not exists public.office_leave_requests (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,
 employee_id uuid not null,leave_type text not null check(leave_type in('annual','sick','casual','unpaid','other')),
 start_date date not null,end_date date not null,days_count integer generated always as(end_date-start_date+1) stored,
 reason text check(reason is null or char_length(reason)<=500),
 status text not null default 'pending' check(status in('pending','approved','rejected','cancelled')),
 manager_notes text check(manager_notes is null or char_length(manager_notes)<=500),
 reviewed_by uuid references auth.users(id) on delete set null,reviewed_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint office_leave_dates_check check(end_date>=start_date and end_date-start_date<=90),
 constraint office_leave_employee_shop_fk foreign key(shop_id,employee_id) references public.office_employees(shop_id,id) on delete restrict
);
create index if not exists office_leave_requests_shop_employee_dates_idx on public.office_leave_requests(shop_id,employee_id,start_date,end_date);
create index if not exists office_leave_requests_reviewed_by_idx on public.office_leave_requests(reviewed_by);
create table if not exists public.office_payroll_records (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,
 employee_id uuid not null,period_start date not null,period_end date not null,
 basic_salary numeric(12,2) not null check(basic_salary>=0 and basic_salary<=100000000),
 additions numeric(12,2) not null default 0 check(additions>=0 and additions<=100000000),
 deductions numeric(12,2) not null default 0 check(deductions>=0 and deductions<=100000000),
 net_amount numeric(12,2) generated always as(basic_salary+additions-deductions) stored,
 status text not null default 'pending' check(status in('pending','paid')),
 payment_method text check(payment_method is null or payment_method in('cash','upi','bank_transfer','cheque','other')),
 payment_reference text check(payment_reference is null or char_length(payment_reference)<=120),paid_at timestamptz,
 notes text check(notes is null or char_length(notes)<=500),
 created_by uuid references auth.users(id) on delete set null default auth.uid(),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint office_payroll_period_check check(period_end>=period_start and period_end-period_start<=45),
 constraint office_payroll_net_check check(deductions<=basic_salary+additions),
 constraint office_payroll_employee_shop_fk foreign key(shop_id,employee_id) references public.office_employees(shop_id,id) on delete restrict,
 constraint office_payroll_payment_state_check check((status='pending' and payment_method is null and paid_at is null) or (status='paid' and payment_method is not null and paid_at is not null))
);
create unique index if not exists office_payroll_employee_period_uidx on public.office_payroll_records(shop_id,employee_id,period_start,period_end);
create index if not exists office_payroll_created_by_idx on public.office_payroll_records(created_by);
alter table public.office_leave_requests enable row level security;
alter table public.office_payroll_records enable row level security;
revoke all on public.office_leave_requests from anon,authenticated;
revoke all on public.office_payroll_records from anon,authenticated;
grant insert(id,shop_id,employee_id,leave_type,start_date,end_date,reason) on public.office_leave_requests to authenticated;
grant select(id,shop_id,employee_id,leave_type,start_date,end_date,days_count,reason,status,manager_notes,reviewed_by,reviewed_at,created_at,updated_at) on public.office_leave_requests to authenticated;
grant update(status,manager_notes) on public.office_leave_requests to authenticated;
grant insert(id,shop_id,employee_id,period_start,period_end,basic_salary,additions,deductions,notes) on public.office_payroll_records to authenticated;
grant select(id,shop_id,employee_id,period_start,period_end,basic_salary,additions,deductions,net_amount,status,payment_method,payment_reference,paid_at,notes,created_by,created_at,updated_at) on public.office_payroll_records to authenticated;
grant update(status,payment_method,payment_reference,notes) on public.office_payroll_records to authenticated;
drop policy if exists office_leave_requests_owner_read on public.office_leave_requests;
create policy office_leave_requests_owner_read on public.office_leave_requests for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists office_leave_requests_owner_insert on public.office_leave_requests;
create policy office_leave_requests_owner_insert on public.office_leave_requests for insert to authenticated with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_leave_requests.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()) and exists(select 1 from public.office_employees e where e.id=office_leave_requests.employee_id and e.shop_id=office_leave_requests.shop_id and e.is_active=true));
drop policy if exists office_leave_requests_owner_update on public.office_leave_requests;
create policy office_leave_requests_owner_update on public.office_leave_requests for update to authenticated using((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_leave_requests.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now())) with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_leave_requests.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()));
drop policy if exists office_payroll_records_owner_read on public.office_payroll_records;
create policy office_payroll_records_owner_read on public.office_payroll_records for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists office_payroll_records_owner_insert on public.office_payroll_records;
create policy office_payroll_records_owner_insert on public.office_payroll_records for insert to authenticated with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_payroll_records.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()) and exists(select 1 from public.office_employees e where e.id=office_payroll_records.employee_id and e.shop_id=office_payroll_records.shop_id and e.is_active=true) and created_by is not distinct from (select auth.uid()));
drop policy if exists office_payroll_records_owner_update on public.office_payroll_records;
create policy office_payroll_records_owner_update on public.office_payroll_records for update to authenticated using((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_payroll_records.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now())) with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_payroll_records.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()));
create or replace function private.guard_office_leave_request_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.employee_id is distinct from old.employee_id or new.leave_type is distinct from old.leave_type or new.start_date is distinct from old.start_date or new.end_date is distinct from old.end_date or new.reason is distinct from old.reason then raise exception 'Leave request details cannot be edited after submission'; end if;
 if old.status='pending' and new.status not in('pending','approved','rejected','cancelled') then raise exception 'Invalid leave request status transition'; elsif old.status in('approved','rejected','cancelled') and new.status is distinct from old.status then raise exception 'A closed leave request cannot be reopened'; end if;
 if new.status='approved' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.employee_id::text,0));
  if exists(select 1 from public.office_leave_requests l where l.shop_id=new.shop_id and l.employee_id=new.employee_id and l.id<>new.id and l.status='approved' and l.start_date<=new.end_date and l.end_date>=new.start_date) then raise exception 'This employee already has approved leave overlapping these dates'; end if;
  new.reviewed_by:=auth.uid();new.reviewed_at:=pg_catalog.now();
 elsif new.status in('rejected','cancelled') then new.reviewed_by:=auth.uid();new.reviewed_at:=pg_catalog.now(); end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_office_leave_request_update() from public,anon,authenticated;
drop trigger if exists office_leave_requests_guard_update on public.office_leave_requests;
create trigger office_leave_requests_guard_update before update on public.office_leave_requests for each row execute function private.guard_office_leave_request_update();
create or replace function private.guard_office_payroll_record_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.employee_id is distinct from old.employee_id or new.period_start is distinct from old.period_start or new.period_end is distinct from old.period_end or new.basic_salary is distinct from old.basic_salary or new.additions is distinct from old.additions or new.deductions is distinct from old.deductions or new.created_by is distinct from old.created_by then raise exception 'Payroll amounts and employee/period details cannot be edited after creation'; end if;
 if old.status='paid' and new.status is distinct from old.status then raise exception 'A paid payroll record cannot be reopened'; elsif old.status='pending' and new.status not in('pending','paid') then raise exception 'Invalid payroll status transition'; end if;
 if new.status='paid' then if new.payment_method is null then raise exception 'Select a payment method before marking payroll paid'; end if;new.paid_at:=coalesce(old.paid_at,pg_catalog.now()); else new.payment_method:=null;new.payment_reference:=null;new.paid_at:=null; end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_office_payroll_record_update() from public,anon,authenticated;
drop trigger if exists office_payroll_records_guard_update on public.office_payroll_records;
create trigger office_payroll_records_guard_update before update on public.office_payroll_records for each row execute function private.guard_office_payroll_record_update();
