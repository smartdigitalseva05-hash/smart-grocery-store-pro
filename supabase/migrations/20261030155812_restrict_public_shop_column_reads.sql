revoke all on public.shops from anon;
grant select(id,name,city) on public.shops to anon;
grant execute on function public.is_public_shop_active(uuid) to anon;
