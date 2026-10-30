drop policy if exists subcat_admin on public.subcategories;
create policy subcat_admin_insert on public.subcategories for insert to authenticated with check (private.is_super_admin());
create policy subcat_admin_update on public.subcategories for update to authenticated using (private.is_super_admin()) with check (private.is_super_admin());
create policy subcat_admin_delete on public.subcategories for delete to authenticated using (private.is_super_admin());