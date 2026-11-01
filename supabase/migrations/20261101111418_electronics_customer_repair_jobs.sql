create unique index if not exists electronics_inventory_shop_id_id_uidx on public.electronics_inventory(shop_id,id);
create table if not exists public.electronics_service_jobs (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,inventory_id uuid,
 customer_id uuid references auth.users(id) on delete set null,
 customer_name text not null check(char_length(btrim(customer_name)) between 1 and 120),
 customer_phone text not null check(customer_phone ~ '^[0-9+() -]{7,20}$' and char_length(regexp_replace(customer_phone,'[^0-9]','','g')) between 7 and 15),
 device_name text not null check(char_length(btrim(device_name)) between 1 and 120),
 brand text check(brand is null or char_length(brand)<=80),model text check(model is null or char_length(model)<=80),
 serial_or_imei text check(serial_or_imei is null or char_length(serial_or_imei)<=100),
 issue_description text not null check(char_length(btrim(issue_description)) between 5 and 1000),
 customer_notes text check(customer_notes is null or char_length(customer_notes)<=500),diagnosis text check(diagnosis is null or char_length(diagnosis)<=1000),
 estimated_cost numeric(12,2) check(estimated_cost is null or (estimated_cost>=0 and estimated_cost<=100000000)),
 approved_cost numeric(12,2) check(approved_cost is null or (approved_cost>=0 and approved_cost<=100000000)),
 final_cost numeric(12,2) check(final_cost is null or (final_cost>=0 and final_cost<=100000000)),
 status text not null default 'received' check(status in('received','diagnosed','awaiting_approval','approved','in_repair','ready','delivered','cancelled')),
 due_at date,shopkeeper_notes text check(shopkeeper_notes is null or char_length(shopkeeper_notes)<=500),
 received_at timestamptz not null default now(),delivered_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint electronics_service_job_inventory_shop_fk foreign key(shop_id,inventory_id) references public.electronics_inventory(shop_id,id) on delete restrict
);
create index if not exists electronics_service_jobs_shop_created_idx on public.electronics_service_jobs(shop_id,created_at desc);
create index if not exists electronics_service_jobs_shop_status_created_idx on public.electronics_service_jobs(shop_id,status,created_at desc);
create index if not exists electronics_service_jobs_customer_id_idx on public.electronics_service_jobs(customer_id);
create index if not exists electronics_service_jobs_inventory_id_idx on public.electronics_service_jobs(inventory_id);
alter table public.electronics_service_jobs enable row level security;
revoke all on public.electronics_service_jobs from anon,authenticated;
grant insert(id,shop_id,customer_id,customer_name,customer_phone,device_name,brand,model,serial_or_imei,issue_description,customer_notes) on public.electronics_service_jobs to anon,authenticated;
grant select(id,shop_id,inventory_id,customer_id,customer_name,customer_phone,device_name,brand,model,serial_or_imei,issue_description,customer_notes,diagnosis,estimated_cost,approved_cost,final_cost,status,due_at,shopkeeper_notes,received_at,delivered_at,created_at,updated_at) on public.electronics_service_jobs to authenticated;
grant update(inventory_id,diagnosis,estimated_cost,approved_cost,final_cost,status,due_at,shopkeeper_notes) on public.electronics_service_jobs to authenticated;
create or replace function private.is_active_electronics_service_shop(p_shop_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.shops s join public.profiles p on p.id=s.owner_id where s.id=p_shop_id and s.business_type='electronics' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>pg_catalog.now() and p.role='shopkeeper'::public.user_role and p.is_active=true);
$$;
revoke all on function private.is_active_electronics_service_shop(uuid) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.is_active_electronics_service_shop(uuid) to anon,authenticated;
drop policy if exists electronics_service_jobs_public_insert on public.electronics_service_jobs;
create policy electronics_service_jobs_public_insert on public.electronics_service_jobs for insert to anon,authenticated with check(status='received' and inventory_id is null and diagnosis is null and estimated_cost is null and approved_cost is null and final_cost is null and delivered_at is null and customer_id is not distinct from (select auth.uid()) and private.is_active_electronics_service_shop(shop_id));
drop policy if exists electronics_service_jobs_owner_read on public.electronics_service_jobs;
create policy electronics_service_jobs_owner_read on public.electronics_service_jobs for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists electronics_service_jobs_owner_update on public.electronics_service_jobs;
create policy electronics_service_jobs_owner_update on public.electronics_service_jobs for update to authenticated using((select private.is_shop_owner(shop_id)) and (select private.is_active_electronics_service_shop(shop_id))) with check((select private.is_shop_owner(shop_id)) and (select private.is_active_electronics_service_shop(shop_id)));
create or replace function private.guard_electronics_service_job_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.customer_id is distinct from old.customer_id or new.customer_name is distinct from old.customer_name or new.customer_phone is distinct from old.customer_phone or new.device_name is distinct from old.device_name or new.brand is distinct from old.brand or new.model is distinct from old.model or new.serial_or_imei is distinct from old.serial_or_imei or new.issue_description is distinct from old.issue_description or new.customer_notes is distinct from old.customer_notes or new.received_at is distinct from old.received_at then raise exception 'Customer repair request details cannot be edited by the shop'; end if;
 if old.status='received' and new.status not in('received','diagnosed','cancelled') then raise exception 'Invalid received-job status transition'; elsif old.status='diagnosed' and new.status not in('diagnosed','awaiting_approval','approved','in_repair','cancelled') then raise exception 'Invalid diagnosed-job status transition'; elsif old.status='awaiting_approval' and new.status not in('awaiting_approval','approved','cancelled') then raise exception 'Invalid estimate-approval status transition'; elsif old.status='approved' and new.status not in('approved','in_repair','cancelled') then raise exception 'Invalid approved-job status transition'; elsif old.status='in_repair' and new.status not in('in_repair','ready','cancelled') then raise exception 'Invalid in-repair status transition'; elsif old.status='ready' and new.status not in('ready','delivered') then raise exception 'Only a ready job can be delivered'; elsif old.status in('delivered','cancelled') and new.status is distinct from old.status then raise exception 'A closed repair job cannot be reopened'; end if;
 if new.status='awaiting_approval' and new.estimated_cost is null then raise exception 'Enter an estimated cost before requesting customer approval'; end if;
 if new.status in('approved','in_repair') and new.approved_cost is null then raise exception 'Enter the customer-approved repair cost before starting repair'; end if;
 if new.status='ready' and new.final_cost is null then raise exception 'Enter the final repair cost before marking the device ready'; end if;
 if new.status='delivered' then new.delivered_at:=coalesce(old.delivered_at,pg_catalog.now()); end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_electronics_service_job_update() from public,anon,authenticated;
drop trigger if exists electronics_service_jobs_guard_update on public.electronics_service_jobs;
create trigger electronics_service_jobs_guard_update before update on public.electronics_service_jobs for each row execute function private.guard_electronics_service_job_update();
