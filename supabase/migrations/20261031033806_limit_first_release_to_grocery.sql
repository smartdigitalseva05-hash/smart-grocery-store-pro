alter table public.shops add column if not exists business_type text not null default 'grocery';
alter table public.shops drop constraint if exists shops_business_type_allowed;
alter table public.shops add constraint shops_business_type_allowed check(business_type='grocery');
comment on column public.shops.business_type is 'Business vertical selected during application; immutable for shopkeepers after submission.';
