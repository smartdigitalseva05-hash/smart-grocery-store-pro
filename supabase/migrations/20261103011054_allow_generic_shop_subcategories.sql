
alter policy subcat_read on public.subcategories
using (
  private.is_super_admin()
  or exists (
    select 1
    from public.categories c
    join public.shops s
      on c.business_type is null
      or s.business_type = c.business_type
    where c.id = public.subcategories.category_id
      and s.owner_id = (select auth.uid())
      and private.is_shop_owner(s.id)
  )
);
