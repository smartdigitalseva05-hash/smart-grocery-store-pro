
do $$
declare
  fn_name text;
  fn_oid oid;
  fn_def text;
begin
  foreach fn_name in array array[
    'cancel_order',
    'create_subscription_checkout',
    'place_order',
    'update_order_status_by_shopkeeper',
    'verify_payment_and_activate'
  ]
  loop
    select p.oid into fn_oid
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=fn_name;

    if fn_oid is null then
      raise exception 'Expected public function % was not found', fn_name;
    end if;

    fn_def := pg_get_functiondef(fn_oid);
    fn_def := replace(fn_def, 'FUNCTION public.' || fn_name || '(', 'FUNCTION private.' || fn_name || '(');
    execute fn_def;
  end loop;
end;
$$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns boolean
language sql
security invoker
set search_path = pg_catalog, public
as $$ select private.cancel_order(p_order_id, p_reason); $$;

create or replace function public.create_subscription_checkout(p_shop_id uuid, p_plan_id uuid, p_billing_cycle text)
returns jsonb
language sql
security invoker
set search_path = pg_catalog, public
as $$ select private.create_subscription_checkout(p_shop_id, p_plan_id, p_billing_cycle); $$;

create or replace function public.place_order(p_shop_id uuid, p_address_id uuid, p_items jsonb)
returns uuid
language sql
security invoker
set search_path = pg_catalog, public
as $$ select private.place_order(p_shop_id, p_address_id, p_items); $$;

create or replace function public.update_order_status_by_shopkeeper(p_order_id uuid, p_new_status public.order_status)
returns boolean
language sql
security invoker
set search_path = pg_catalog, public
as $$ select private.update_order_status_by_shopkeeper(p_order_id, p_new_status); $$;

create or replace function public.verify_payment_and_activate(p_payment_id uuid)
returns boolean
language sql
security invoker
set search_path = pg_catalog, public
as $$ select private.verify_payment_and_activate(p_payment_id); $$;

revoke all on function private.cancel_order(uuid,text) from public, anon;
revoke all on function private.create_subscription_checkout(uuid,uuid,text) from public, anon;
revoke all on function private.place_order(uuid,uuid,jsonb) from public, anon;
revoke all on function private.update_order_status_by_shopkeeper(uuid,public.order_status) from public, anon;
revoke all on function private.verify_payment_and_activate(uuid) from public, anon;

grant execute on function private.cancel_order(uuid,text) to authenticated;
grant execute on function private.create_subscription_checkout(uuid,uuid,text) to authenticated;
grant execute on function private.place_order(uuid,uuid,jsonb) to authenticated;
grant execute on function private.update_order_status_by_shopkeeper(uuid,public.order_status) to authenticated;
grant execute on function private.verify_payment_and_activate(uuid) to authenticated, service_role;

revoke all on function public.cancel_order(uuid,text) from public, anon;
revoke all on function public.create_subscription_checkout(uuid,uuid,text) from public, anon;
revoke all on function public.place_order(uuid,uuid,jsonb) from public, anon;
revoke all on function public.update_order_status_by_shopkeeper(uuid,public.order_status) from public, anon;
revoke all on function public.verify_payment_and_activate(uuid) from public, anon;

grant execute on function public.cancel_order(uuid,text) to authenticated;
grant execute on function public.create_subscription_checkout(uuid,uuid,text) to authenticated;
grant execute on function public.place_order(uuid,uuid,jsonb) to authenticated;
grant execute on function public.update_order_status_by_shopkeeper(uuid,public.order_status) to authenticated;
grant execute on function public.verify_payment_and_activate(uuid) to authenticated, service_role;
grant usage on schema private to service_role;
