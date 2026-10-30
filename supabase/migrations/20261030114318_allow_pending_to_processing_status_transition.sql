
create or replace function public.validate_status_transition(
  old_s public.order_status,
  new_s public.order_status
)
returns boolean
language sql
immutable
set search_path = pg_catalog, public
as $$
  select (
    (old_s = 'pending' and new_s in ('paid','processing','cancelled'))
    or (old_s = 'paid' and new_s in ('processing','cancelled','refunded'))
    or (old_s = 'processing' and new_s in ('out_for_delivery','cancelled'))
    or (old_s = 'out_for_delivery' and new_s in ('delivered','cancelled'))
    or (old_s is null and new_s = 'pending')
  );
$$;
