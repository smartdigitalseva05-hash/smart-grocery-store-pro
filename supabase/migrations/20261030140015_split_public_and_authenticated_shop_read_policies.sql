
drop policy if exists shops_read on public.shops;
drop policy if exists shops_read_public on public.shops;
drop policy if exists shops_read_authenticated on public.shops;

create policy shops_read_public
on public.shops
for select
to anon
using (is_active = true);

create policy shops_read_authenticated
on public.shops
for select
to authenticated
using (
  is_active = true
  or owner_id = (select auth.uid())
  or private.is_super_admin()
);
