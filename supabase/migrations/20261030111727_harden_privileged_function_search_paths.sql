
alter function public.cancel_order(uuid,text) set search_path = pg_catalog, public;
alter function public.is_shop_owner(uuid) set search_path = pg_catalog, public;
alter function public.is_super_admin() set search_path = pg_catalog, public;
alter function public.place_order(uuid,uuid,jsonb) set search_path = pg_catalog, public;
alter function public.update_order_status_by_shopkeeper(uuid,public.order_status) set search_path = pg_catalog, public;
alter function public.verify_payment_and_activate(uuid) set search_path = pg_catalog, public;
