create or replace function private.is_active_free_trial(p_shop_id uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
 select exists(select 1 from public.shop_trials t join public.shops s on s.id=t.shop_id
  where t.shop_id=p_shop_id and t.status='active' and t.ends_at>now() and s.is_active=true
   and s.status='active'::public.shop_status and s.subscription_expires_at=t.ends_at);
$$;

create or replace function private.start_free_trial(p_shop_id uuid)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare v_uid uuid:=auth.uid(); v_shop public.shops%rowtype; v_plan public.subscription_plans%rowtype; v_trial public.shop_trials%rowtype;
begin
 if v_uid is null then raise exception 'Sign in is required to start the free trial' using errcode='42501'; end if;
 if not exists(select 1 from public.profiles p where p.id=v_uid and p.role='shopkeeper'::public.user_role and p.is_active=true) then raise exception 'An active shopkeeper account is required' using errcode='42501'; end if;
 select * into v_shop from public.shops where id=p_shop_id and owner_id=v_uid for update;
 if not found then raise exception 'This grocery shop does not belong to your account' using errcode='42501'; end if;
 if v_shop.business_type<>'grocery' then raise exception 'The first release free trial is available for grocery shops only' using errcode='22023'; end if;
 if v_shop.status='suspended'::public.shop_status then raise exception 'Suspended shops cannot start a free trial' using errcode='55000'; end if;
 select * into v_trial from public.shop_trials where owner_id=v_uid for update;
 if found then
  if v_trial.shop_id=p_shop_id and v_trial.status='active' and v_trial.ends_at>now() then
   return jsonb_build_object('started',true,'already_started',true,'status','active','started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'days',7);
  end if;
  raise exception 'This account has already used its one-time free trial' using errcode='55000';
 end if;
 if v_shop.is_active or v_shop.status='active'::public.shop_status then raise exception 'This shop is already active; the free trial cannot be applied to an active shop' using errcode='55000'; end if;
 select * into v_plan from public.subscription_plans where slug='basic' and is_active=true limit 1;
 if not found then raise exception 'The active Basic plan is unavailable; contact platform support' using errcode='55000'; end if;
 insert into public.shop_trials(owner_id,shop_id,status,started_at,ends_at) values(v_uid,p_shop_id,'active',now(),now()+interval '7 days') returning * into v_trial;
 perform set_config('app.free_trial_activation','true',true);
 update public.shops set is_active=true,status='active'::public.shop_status,subscription_plan_id=v_plan.id,subscription_expires_at=v_trial.ends_at where id=p_shop_id and owner_id=v_uid;
 return jsonb_build_object('started',true,'already_started',false,'status','active','started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'days',7,'plan_name',v_plan.name,'max_products',v_plan.max_products);
end;
$$;
create or replace function public.start_free_trial(p_shop_id uuid)
returns jsonb language sql set search_path=pg_catalog,public,private as $$
 select private.start_free_trial(p_shop_id);
$$;
grant usage on schema private to authenticated;
grant execute on function private.start_free_trial(uuid) to authenticated;
grant execute on function public.start_free_trial(uuid) to authenticated;
