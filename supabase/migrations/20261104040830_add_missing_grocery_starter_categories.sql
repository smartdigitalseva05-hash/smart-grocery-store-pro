-- Add missing Grocery category rows referenced by its starter catalogue.
insert into public.categories (name, slug, business_type, is_active)
values
  ('Grocery Personal Care','grocery-personal-care','grocery',true),
  ('Grocery Home Cleaning','grocery-home-cleaning','grocery',true),
  ('Grocery Baby & Health Essentials','grocery-baby-health-essentials','grocery',true)
on conflict (slug) do update
set name=excluded.name, business_type=excluded.business_type, is_active=true;
