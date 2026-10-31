alter table public.shops drop constraint if exists shops_business_type_allowed;
alter table public.shops add constraint shops_business_type_allowed check (business_type = any (array['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other']::text[]));
comment on column public.shops.business_type is 'Business vertical selected during application; immutable for shopkeepers after submission.';

create or replace function private.guard_shop_business_type()
returns trigger language plpgsql set search_path=pg_catalog,public,private as $$
begin
 if new.business_type is distinct from old.business_type and not private.is_super_admin() then
  raise exception 'Business type cannot be changed after shop registration. Contact Super Admin.' using errcode='42501';
 end if;
 return new;
end;
$$;
drop trigger if exists trg_guard_shop_business_type on public.shops;
create trigger trg_guard_shop_business_type before update of business_type on public.shops
for each row execute function private.guard_shop_business_type();
