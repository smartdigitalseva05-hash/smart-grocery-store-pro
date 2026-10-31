create or replace function private.place_order_with_notes(
  p_shop_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $function$
declare
  v_order_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_order_id := private.place_order(p_shop_id, p_address_id, p_items);

  update public.orders
  set notes = nullif(left(btrim(coalesce(p_notes, '')), 500), '')
  where id = v_order_id
    and customer_id = auth.uid();

  if not found then
    raise exception 'Could not save order notes for this customer order'
      using errcode = '42501';
  end if;

  return v_order_id;
end;
$function$;

revoke all on function private.place_order_with_notes(uuid, uuid, jsonb, text) from public, anon;
grant execute on function private.place_order_with_notes(uuid, uuid, jsonb, text) to authenticated;

create or replace function public.place_order_with_notes(
  p_shop_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_notes text default null
)
returns uuid
language sql
security invoker
set search_path = pg_catalog, public, private
as $function$
  select private.place_order_with_notes(p_shop_id, p_address_id, p_items, p_notes);
$function$;

revoke all on function public.place_order_with_notes(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.place_order_with_notes(uuid, uuid, jsonb, text) to authenticated;