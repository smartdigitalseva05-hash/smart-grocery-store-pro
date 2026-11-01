create unique index if not exists hotel_rooms_shop_id_id_uidx on public.hotel_rooms(shop_id,id);
create table if not exists public.hotel_housekeeping_tasks (
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id) on delete cascade,room_id uuid not null,
 task_type text not null check(task_type in('cleaning','linen_change','inspection','maintenance','other')),
 assigned_to text check(assigned_to is null or char_length(assigned_to)<=120),due_at date,
 status text not null default 'pending' check(status in('pending','in_progress','completed','cancelled')),
 notes text check(notes is null or char_length(notes)<=500),
 created_by uuid references auth.users(id) on delete set null default auth.uid(),completed_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint hotel_housekeeping_room_shop_fk foreign key(shop_id,room_id) references public.hotel_rooms(shop_id,id) on delete restrict
);
create index if not exists hotel_housekeeping_tasks_shop_created_idx on public.hotel_housekeeping_tasks(shop_id,created_at desc);
create index if not exists hotel_housekeeping_tasks_shop_status_due_idx on public.hotel_housekeeping_tasks(shop_id,status,due_at);
create index if not exists hotel_housekeeping_tasks_created_by_idx on public.hotel_housekeeping_tasks(created_by);
alter table public.hotel_housekeeping_tasks enable row level security;
revoke all on public.hotel_housekeeping_tasks from anon,authenticated;
grant insert(id,shop_id,room_id,task_type,assigned_to,due_at,notes) on public.hotel_housekeeping_tasks to authenticated;
grant select(id,shop_id,room_id,task_type,assigned_to,due_at,status,notes,created_by,completed_at,created_at,updated_at) on public.hotel_housekeeping_tasks to authenticated;
grant update(status,assigned_to,due_at,notes) on public.hotel_housekeeping_tasks to authenticated;
drop policy if exists hotel_housekeeping_tasks_owner_read on public.hotel_housekeeping_tasks;
create policy hotel_housekeeping_tasks_owner_read on public.hotel_housekeeping_tasks for select to authenticated using((select private.is_shop_owner(shop_id)) or (select private.is_super_admin()));
drop policy if exists hotel_housekeeping_tasks_owner_insert on public.hotel_housekeeping_tasks;
create policy hotel_housekeeping_tasks_owner_insert on public.hotel_housekeeping_tasks for insert to authenticated with check((select private.is_shop_owner(shop_id)) and (select private.is_active_hotel_booking_shop(shop_id)) and created_by is not distinct from (select auth.uid()) and exists(select 1 from public.hotel_rooms r where r.id=hotel_housekeeping_tasks.room_id and r.shop_id=hotel_housekeeping_tasks.shop_id and r.is_active=true));
drop policy if exists hotel_housekeeping_tasks_owner_update on public.hotel_housekeeping_tasks;
create policy hotel_housekeeping_tasks_owner_update on public.hotel_housekeeping_tasks for update to authenticated using((select private.is_shop_owner(shop_id)) and (select private.is_active_hotel_booking_shop(shop_id))) with check((select private.is_shop_owner(shop_id)) and (select private.is_active_hotel_booking_shop(shop_id)));
create or replace function private.guard_hotel_housekeeping_task_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.room_id is distinct from old.room_id or new.task_type is distinct from old.task_type or new.created_by is distinct from old.created_by then raise exception 'Housekeeping task room and task type cannot be changed'; end if;
 if old.status='pending' and new.status not in('pending','in_progress','completed','cancelled') then raise exception 'Invalid pending housekeeping task transition'; elsif old.status='in_progress' and new.status not in('in_progress','completed','cancelled') then raise exception 'Invalid in-progress housekeeping task transition'; elsif old.status in('completed','cancelled') and new.status is distinct from old.status then raise exception 'A closed housekeeping task cannot be reopened'; end if;
 if new.status='completed' then new.completed_at:=coalesce(old.completed_at,pg_catalog.now()); elsif new.status='cancelled' then new.completed_at:=null; end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_hotel_housekeeping_task_update() from public,anon,authenticated;
drop trigger if exists hotel_housekeeping_tasks_guard_update on public.hotel_housekeeping_tasks;
create trigger hotel_housekeeping_tasks_guard_update before update on public.hotel_housekeeping_tasks for each row execute function private.guard_hotel_housekeeping_task_update();
