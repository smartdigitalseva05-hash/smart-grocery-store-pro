
create or replace function public.owner_set_shop_status(
  p_shop_id uuid,
  p_status public.shop_status
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_old public.shops%rowtype;
  v_active boolean;
begin
  if auth.uid() is null or not public.is_super_admin() then
    raise exception 'Only active super_admin can change shop status'
      using errcode = '42501';
  end if;

  if p_shop_id is null or p_status is null then
    raise exception 'Shop ID and status are required'
      using errcode = '22023';
  end if;

  select * into v_old
  from public.shops
  where id = p_shop_id
  for update;

  if not found then
    raise exception 'Shop not found' using errcode = 'P0002';
  end if;

  v_active := (p_status = 'active'::public.shop_status);

  update public.shops
  set status = p_status,
      is_active = v_active,
      updated_at = now()
  where id = p_shop_id;

  insert into public.audit_logs(actor_id, action, entity, entity_id, old_data, new_data)
  values (
    auth.uid(),
    'update'::public.audit_action,
    'shop',
    p_shop_id,
    jsonb_build_object('status', v_old.status, 'is_active', v_old.is_active),
    jsonb_build_object('status', p_status, 'is_active', v_active)
  );

  return jsonb_build_object(
    'shop_id', p_shop_id,
    'status', p_status,
    'is_active', v_active,
    'updated_at', now()
  );
end;
$$;

revoke all on function public.owner_set_shop_status(uuid, public.shop_status) from public, anon;
grant execute on function public.owner_set_shop_status(uuid, public.shop_status) to authenticated;

grant insert on public.audit_logs to authenticated;
drop policy if exists audit_admin_insert on public.audit_logs;
create policy audit_admin_insert
on public.audit_logs
for insert
to authenticated
with check (actor_id = (select auth.uid()) and public.is_super_admin());
