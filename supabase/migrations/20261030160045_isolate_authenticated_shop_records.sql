drop policy if exists shops_read_authenticated on public.shops;
create policy shops_read_authenticated on public.shops for select to authenticated
using(owner_id=(select auth.uid()) or private.is_super_admin());
