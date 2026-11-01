create table if not exists public.office_tasks (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,employee_id uuid,
 title text not null check(char_length(btrim(title)) between 1 and 120),
 description text check(description is null or char_length(description)<=1000),
 priority text not null default 'normal' check(priority in('low','normal','high','urgent')),
 due_at date,status text not null default 'open' check(status in('open','in_progress','blocked','completed','cancelled')),
 created_by uuid references auth.users(id) on delete set null default auth.uid(),completed_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint office_tasks_employee_shop_fk foreign key(shop_id,employee_id) references public.office_employees(shop_id,id) on delete restrict
);
create index if not exists office_tasks_shop_status_due_idx on public.office_tasks(shop_id,status,due_at);
create index if not exists office_tasks_shop_employee_idx on public.office_tasks(shop_id,employee_id);
create index if not exists office_tasks_created_by_idx on public.office_tasks(created_by);
alter table public.office_tasks enable row level security;
revoke all on public.office_tasks from anon,authenticated;
grant insert(id,shop_id,employee_id,title,description,priority,due_at) on public.office_tasks to authenticated;
grant select(id,shop_id,employee_id,title,description,priority,due_at,status,created_by,completed_at,created_at,updated_at) on public.office_tasks to authenticated;
grant update(employee_id,title,description,priority,due_at,status) on public.office_tasks to authenticated;
drop policy if exists office_tasks_owner_read on public.office_tasks;
create policy office_tasks_owner_read on public.office_tasks for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists office_tasks_owner_insert on public.office_tasks;
create policy office_tasks_owner_insert on public.office_tasks for insert to authenticated with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_tasks.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()) and created_by is not distinct from (select auth.uid()) and (employee_id is null or exists(select 1 from public.office_employees e where e.id=office_tasks.employee_id and e.shop_id=office_tasks.shop_id and e.is_active=true)));
drop policy if exists office_tasks_owner_update on public.office_tasks;
create policy office_tasks_owner_update on public.office_tasks for update to authenticated using((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_tasks.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now())) with check((select private.is_shop_owner(shop_id)) and exists(select 1 from public.shops s where s.id=office_tasks.shop_id and s.business_type='office_company' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>now()) and (employee_id is null or exists(select 1 from public.office_employees e where e.id=office_tasks.employee_id and e.shop_id=office_tasks.shop_id)));
create or replace function private.guard_office_task_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then raise exception 'Task shop and creator cannot be changed'; end if;
 if old.status='open' and new.status not in('open','in_progress','blocked','completed','cancelled') then raise exception 'Invalid open task transition'; elsif old.status='in_progress' and new.status not in('in_progress','blocked','completed','cancelled') then raise exception 'Invalid in-progress task transition'; elsif old.status='blocked' and new.status not in('blocked','in_progress','cancelled') then raise exception 'Invalid blocked task transition'; elsif old.status in('completed','cancelled') and new.status is distinct from old.status then raise exception 'A closed task cannot be reopened'; end if;
 if new.status='completed' then new.completed_at:=coalesce(old.completed_at,pg_catalog.now()); elsif new.status='cancelled' then new.completed_at:=null; end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_office_task_update() from public,anon,authenticated;
drop trigger if exists office_tasks_guard_update on public.office_tasks;
create trigger office_tasks_guard_update before update on public.office_tasks for each row execute function private.guard_office_task_update();
