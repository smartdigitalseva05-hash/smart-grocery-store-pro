alter function public.owner_dashboard_summary() security invoker;
grant execute on function public.owner_dashboard_summary() to authenticated;
grant select on public.profiles to authenticated;
grant select(id,owner_id,name,slug,description,phone,email,address,city,is_active,status,subscription_plan_id,subscription_expires_at,total_orders_this_month,last_order_reset,created_at,updated_at,logo_url) on public.shops to authenticated;
