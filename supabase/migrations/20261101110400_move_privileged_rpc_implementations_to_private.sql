alter function public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) set schema private;
alter function private.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) security definer;
alter function private.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) set search_path='';
alter function public.owner_approve_shop_application(uuid) set schema private;
alter function private.owner_approve_shop_application(uuid) security definer;
alter function private.owner_approve_shop_application(uuid) set search_path='';
alter function public.owner_set_shop_status(uuid,public.shop_status) set schema private;
alter function private.owner_set_shop_status(uuid,public.shop_status) security definer;
alter function private.owner_set_shop_status(uuid,public.shop_status) set search_path='';
alter function public.owner_set_shopkeeper_status(uuid,boolean) set schema private;
alter function private.owner_set_shopkeeper_status(uuid,boolean) security definer;
alter function private.owner_set_shopkeeper_status(uuid,boolean) set search_path='';
revoke all on function private.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) from public,anon;
revoke all on function private.owner_approve_shop_application(uuid) from public,anon;
revoke all on function private.owner_set_shop_status(uuid,public.shop_status) from public,anon;
revoke all on function private.owner_set_shopkeeper_status(uuid,boolean) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) to authenticated;
grant execute on function private.owner_approve_shop_application(uuid) to authenticated;
grant execute on function private.owner_set_shop_status(uuid,public.shop_status) to authenticated;
grant execute on function private.owner_set_shopkeeper_status(uuid,boolean) to authenticated;
create function public.grocery_record_purchase(p_shop_id uuid,p_product_id uuid,p_supplier_id uuid,p_quantity integer,p_unit_cost numeric,p_invoice_number text default null,p_purchase_date date default current_date,p_notes text default null)
returns uuid language sql security invoker set search_path='' as $$
 select private.grocery_record_purchase(p_shop_id,p_product_id,p_supplier_id,p_quantity,p_unit_cost,p_invoice_number,p_purchase_date,p_notes);
$$;
create function public.owner_approve_shop_application(p_shop_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select private.owner_approve_shop_application(p_shop_id); $$;
create function public.owner_set_shop_status(p_shop_id uuid,p_status public.shop_status)
returns jsonb language sql security invoker set search_path='' as $$ select private.owner_set_shop_status(p_shop_id,p_status); $$;
create function public.owner_set_shopkeeper_status(p_user_id uuid,p_is_active boolean)
returns jsonb language sql security invoker set search_path='' as $$ select private.owner_set_shopkeeper_status(p_user_id,p_is_active); $$;
revoke all on function public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) from public,anon;
revoke all on function public.owner_approve_shop_application(uuid) from public,anon;
revoke all on function public.owner_set_shop_status(uuid,public.shop_status) from public,anon;
revoke all on function public.owner_set_shopkeeper_status(uuid,boolean) from public,anon;
grant execute on function public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) to authenticated;
grant execute on function public.owner_approve_shop_application(uuid) to authenticated;
grant execute on function public.owner_set_shop_status(uuid,public.shop_status) to authenticated;
grant execute on function public.owner_set_shopkeeper_status(uuid,boolean) to authenticated;
