alter table public.shops drop constraint if exists shops_business_type_allowed;
alter table public.shops add constraint shops_business_type_allowed check (business_type = any (array['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other']::text[]));
comment on column public.shops.business_type is 'Business vertical selected during application; immutable for shopkeepers after submission.';
