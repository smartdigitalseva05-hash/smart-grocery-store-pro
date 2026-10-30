
create or replace function public.owner_approve_shop_application(p_shop_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_shop public.shops%rowtype;
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null or not public.is_super_admin() then
    raise exception 'Only active Super Admin can approve shop applications'
      using errcode = '42501';
  end if;

  if p_shop_id is null then
    raise exception 'Shop ID is required' using errcode = '22023';
  end if;

  select * into v_shop
  from public.shops
  where id = p_shop_id
  for update;

  if not found then
    raise exception 'Shop application not found' using errcode = 'P0002';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_shop.owner_id
  for update;

  if not found or not v_profile.is_active then
    raise exception 'Shop owner account is missing or inactive'
      using errcode = '55000';
  end if;

  if v_profile.role = 'super_admin'::public.user_role then
    raise exception 'A Super Admin account cannot be converted into a shopkeeper'
      using errcode = '42501';
  end if;

  update public.profiles
  set role = 'shopkeeper'::public.user_role,
      updated_at = now()
  where id = v_shop.owner_id
    and role = 'customer'::public.user_role;

  insert into public.audit_logs(actor_id, action, entity, entity_id, old_data, new_data)
  values (
    auth.uid(),
    'update'::public.audit_action,
    'shop_application',
    p_shop_id,
    jsonb_build_object('profile_role', v_profile.role, 'shop_status', v_shop.status),
    jsonb_build_object('profile_role', 'shopkeeper', 'shop_status', 'inactive', 'approved_for_subscription', true)
  );

  return jsonb_build_object(
    'shop_id', p_shop_id,
    'owner_id', v_shop.owner_id,
    'profile_role', 'shopkeeper',
    'shop_status', v_shop.status,
    'shop_active', v_shop.is_active
  );
end;
$$;

revoke all on function public.owner_approve_shop_application(uuid) from public, anon;
grant execute on function public.owner_approve_shop_application(uuid) to authenticated;
