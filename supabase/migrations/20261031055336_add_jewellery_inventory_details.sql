create table if not exists public.jewellery_product_details (
 id uuid primary key default gen_random_uuid(),
 shop_id uuid not null references public.shops(id) on delete cascade,
 product_id uuid not null unique references public.products(id) on delete cascade,
 item_code text not null check(length(btrim(item_code)) between 1 and 80),
 metal_type text not null check(metal_type in ('gold','silver','platinum','diamond','other')),
 purity text,
 gross_weight_g numeric not null default 0 check(gross_weight_g>=0),
 net_weight_g numeric not null default 0 check(net_weight_g>=0 and net_weight_g<=gross_weight_g),
 stone_weight_ct numeric not null default 0 check(stone_weight_ct>=0),
 making_charge numeric not null default 0 check(making_charge>=0),
 making_charge_type text not null default 'fixed' check(making_charge_type in ('fixed','per_gram','percentage')),
 metal_rate_per_gram numeric check(metal_rate_per_gram is null or metal_rate_per_gram>=0),
 rate_recorded_at timestamptz,
 hallmark_number text,
 certificate_reference text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint jewellery_item_shop_code_unique unique(shop_id,item_code)
);
create index if not exists jewellery_details_shop_idx on public.jewellery_product_details(shop_id);
alter table public.jewellery_product_details enable row level security;
grant select on public.jewellery_product_details to anon,authenticated;
grant insert,update,delete on public.jewellery_product_details to authenticated;
drop policy if exists jewellery_details_read on public.jewellery_product_details;
create policy jewellery_details_read on public.jewellery_product_details for select to anon,authenticated
using(private.is_shop_owner(shop_id) or private.is_super_admin() or (private.is_public_shop_active(shop_id) and exists(select 1 from public.products p where p.id=jewellery_product_details.product_id and p.shop_id=jewellery_product_details.shop_id and p.is_available=true)));
drop policy if exists jewellery_details_insert on public.jewellery_product_details;
create policy jewellery_details_insert on public.jewellery_product_details for insert to authenticated
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=jewellery_product_details.shop_id and s.business_type='jewellery' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.products p where p.id=jewellery_product_details.product_id and p.shop_id=jewellery_product_details.shop_id));
drop policy if exists jewellery_details_update on public.jewellery_product_details;
create policy jewellery_details_update on public.jewellery_product_details for update to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=jewellery_product_details.shop_id and s.business_type='jewellery' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()))
with check(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=jewellery_product_details.shop_id and s.business_type='jewellery' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()) and exists(select 1 from public.products p where p.id=jewellery_product_details.product_id and p.shop_id=jewellery_product_details.shop_id));
drop policy if exists jewellery_details_delete on public.jewellery_product_details;
create policy jewellery_details_delete on public.jewellery_product_details for delete to authenticated
using(private.is_shop_owner(shop_id) and exists(select 1 from public.shops s where s.id=jewellery_product_details.shop_id and s.business_type='jewellery' and s.is_active=true and s.status='active' and s.subscription_expires_at>now()));
