create or replace function public.is_public_shop_active(p_shop_id uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
 select exists(select 1 from public.shops s join public.profiles owner_profile on owner_profile.id=s.owner_id
  where s.id=p_shop_id and s.is_active=true and s.status='active'::public.shop_status
   and s.subscription_expires_at>now() and owner_profile.role='shopkeeper'::public.user_role and owner_profile.is_active=true);
$$;
grant execute on function public.is_public_shop_active(uuid) to anon,authenticated;
drop policy if exists shops_read_public on public.shops;
create policy shops_read_public on public.shops for select to anon using(public.is_public_shop_active(id));
drop policy if exists products_read_public on public.products;
create policy products_read_public on public.products for select to anon using(public.is_public_shop_active(shop_id));
