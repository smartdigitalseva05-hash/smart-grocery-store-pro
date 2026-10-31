create or replace function public.owner_set_shopkeeper_status(p_user_id uuid,p_is_active boolean)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_profile public.profiles%rowtype;
begin
 if auth.uid() is null or not private.is_super_admin() then raise exception 'Only active Super Admin can change shopkeeper accounts' using errcode='42501'; end if;
 if p_user_id is null or p_is_active is null then raise exception 'Shopkeeper ID and account status are required' using errcode='22023'; end if;
 select * into v_profile from public.profiles where id=p_user_id for update;
 if not found or v_profile.role<>'shopkeeper'::public.user_role then raise exception 'Shopkeeper account not found' using errcode='P0002'; end if;
 if v_profile.is_active is distinct from p_is_active then
  update public.profiles set is_active=p_is_active,updated_at=now() where id=p_user_id;
  insert into public.audit_logs(actor_id,action,entity,entity_id,old_data,new_data)
  values(auth.uid(),'update'::public.audit_action,'shopkeeper_account',p_user_id,
   jsonb_build_object('is_active',v_profile.is_active,'role',v_profile.role),
   jsonb_build_object('is_active',p_is_active,'role',v_profile.role));
 end if;
 return jsonb_build_object('user_id',p_user_id,'role','shopkeeper','is_active',p_is_active,'updated_at',now());
end;
$$;
grant execute on function public.owner_set_shopkeeper_status(uuid,boolean) to authenticated;
