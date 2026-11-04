
alter policy cat_read on public.categories
to authenticated
using (
  private.is_super_admin()
  or exists (
    select 1
    from public.shops s
    where s.owner_id = (select auth.uid())
      and private.is_shop_owner(s.id)
      and (
        public.categories.business_type is null
        or public.categories.business_type = s.business_type
      )
  )
);

alter policy subcat_read on public.subcategories
to authenticated
using (
  private.is_super_admin()
  or exists (
    select 1
    from public.categories c
    join public.shops s on s.business_type = c.business_type
    where c.id = public.subcategories.category_id
      and s.owner_id = (select auth.uid())
      and private.is_shop_owner(s.id)
      and (
        c.business_type is null
        or c.business_type = s.business_type
      )
  )
);
