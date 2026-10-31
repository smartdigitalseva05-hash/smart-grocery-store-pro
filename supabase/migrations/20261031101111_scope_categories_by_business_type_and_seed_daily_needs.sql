alter table public.categories
  add column if not exists business_type text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.categories'::regclass
      and conname = 'categories_business_type_check'
  ) then
    alter table public.categories
      add constraint categories_business_type_check
      check (
        business_type is null or business_type in (
          'grocery','daily_needs','garments','jewellery','restaurant',
          'hotel','office_company','electronics','medical','digital_services','other'
        )
      );
  end if;
end $$;

update public.categories
set business_type = 'grocery'
where business_type is null;

insert into public.categories (name, slug, business_type, is_active)
values
  ('Personal Care', 'daily-needs-personal-care', 'daily_needs', true),
  ('Baby Care', 'daily-needs-baby-care', 'daily_needs', true),
  ('Home Cleaning', 'daily-needs-home-cleaning', 'daily_needs', true),
  ('Household Utilities', 'daily-needs-household-utilities', 'daily_needs', true),
  ('Kitchen Essentials', 'daily-needs-kitchen-essentials', 'daily_needs', true),
  ('Beverages', 'daily-needs-beverages', 'daily_needs', true),
  ('Snacks', 'daily-needs-snacks', 'daily_needs', true),
  ('Stationery', 'daily-needs-stationery', 'daily_needs', true)
on conflict (slug) do update
set business_type = excluded.business_type,
    is_active = true;