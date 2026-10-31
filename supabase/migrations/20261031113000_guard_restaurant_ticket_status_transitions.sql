-- Enforce forward-only restaurant kitchen ticket status transitions.
-- Allowed: new -> preparing/cancelled; preparing -> ready/cancelled;
-- ready -> served/cancelled. Served and cancelled are terminal states.
create or replace function private.guard_restaurant_ticket_status_transition()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $function$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if (old.status = 'new' and new.status in ('preparing', 'cancelled'))
     or (old.status = 'preparing' and new.status in ('ready', 'cancelled'))
     or (old.status = 'ready' and new.status in ('served', 'cancelled')) then
    return new;
  end if;

  raise exception 'Invalid restaurant ticket status transition: % -> %', old.status, new.status
    using errcode = '23514';
end;
$function$;

drop trigger if exists guard_restaurant_ticket_status_transition on public.restaurant_kitchen_tickets;
create trigger guard_restaurant_ticket_status_transition
before update of status on public.restaurant_kitchen_tickets
for each row execute function private.guard_restaurant_ticket_status_transition();
