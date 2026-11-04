
create table if not exists public.shop_storefront_settings (
  shop_id uuid primary key references public.shops(id) on delete cascade,
  announcement text,
  banner_url text,
  logo_url text,
  theme_key text not null default 'emerald' check (theme_key in ('emerald','blue','rose','amber','slate')),
  minimum_order_amount numeric(12,2) not null default 0 check (minimum_order_amount >= 0),
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  free_delivery_threshold numeric(12,2) check (free_delivery_threshold is null or free_delivery_threshold >= 0),
  delivery_enabled boolean not null default true,
  pickup_enabled boolean not null default true,
  store_open boolean not null default true,
  return_policy text,
  privacy_policy text,
  terms_text text,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_delivery_zones (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  zone_name text not null check (length(trim(zone_name)) between 2 and 100),
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  minimum_order_amount numeric(12,2) not null default 0 check (minimum_order_amount >= 0),
  estimated_delivery_minutes integer check (estimated_delivery_minutes is null or estimated_delivery_minutes between 1 and 10080),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(shop_id,pincode)
);

create table if not exists public.shop_coupons (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9_-]{3,32}$'),
  discount_type text not null check (discount_type in ('percentage','fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  minimum_order_amount numeric(12,2) not null default 0 check (minimum_order_amount >= 0),
  maximum_discount numeric(12,2) check (maximum_discount is null or maximum_discount >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  usage_limit integer check (usage_limit is null or usage_limit > 0),
  used_count integer not null default 0 check (used_count >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(shop_id,code),
  check (discount_type <> 'percentage' or discount_value <= 100),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table if not exists public.shop_product_reviews (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text check (review_text is null or length(review_text) <= 2000),
  is_approved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id,product_id,customer_id)
);

create index if not exists shop_delivery_zones_shop_active_idx on public.shop_delivery_zones(shop_id,is_active,pincode);
create index if not exists shop_coupons_shop_active_idx on public.shop_coupons(shop_id,is_active,code);
create index if not exists shop_product_reviews_product_approved_idx on public.shop_product_reviews(product_id,is_approved,created_at desc);
create index if not exists shop_product_reviews_shop_idx on public.shop_product_reviews(shop_id,created_at desc);

alter table public.shop_storefront_settings enable row level security;
alter table public.shop_delivery_zones enable row level security;
alter table public.shop_coupons enable row level security;
alter table public.shop_product_reviews enable row level security;

revoke all on public.shop_storefront_settings, public.shop_delivery_zones, public.shop_coupons, public.shop_product_reviews from anon;
grant select,insert,update,delete on public.shop_storefront_settings, public.shop_delivery_zones, public.shop_coupons, public.shop_product_reviews to authenticated;

drop policy if exists storefront_settings_read on public.shop_storefront_settings;
create policy storefront_settings_read on public.shop_storefront_settings for select to authenticated
using (private.is_shop_owner(shop_id) or private.is_public_shop_active(shop_id));
drop policy if exists storefront_settings_owner_write on public.shop_storefront_settings;
create policy storefront_settings_owner_write on public.shop_storefront_settings for all to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id) and (updated_by is null or updated_by = (select auth.uid())));

drop policy if exists delivery_zones_read on public.shop_delivery_zones;
create policy delivery_zones_read on public.shop_delivery_zones for select to authenticated
using (private.is_shop_owner(shop_id) or (is_active and private.is_public_shop_active(shop_id)));
drop policy if exists delivery_zones_owner_write on public.shop_delivery_zones;
create policy delivery_zones_owner_write on public.shop_delivery_zones for all to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

drop policy if exists coupons_owner_only on public.shop_coupons;
create policy coupons_owner_only on public.shop_coupons for all to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

drop policy if exists product_reviews_read on public.shop_product_reviews;
create policy product_reviews_read on public.shop_product_reviews for select to authenticated
using ((is_approved and private.is_public_shop_active(shop_id)) or private.is_shop_owner(shop_id));
drop policy if exists product_reviews_customer_insert on public.shop_product_reviews;
create policy product_reviews_customer_insert on public.shop_product_reviews for insert to authenticated
with check (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.id = shop_product_reviews.order_id
      and o.shop_id = shop_product_reviews.shop_id
      and o.customer_id = (select auth.uid())
      and o.status = 'delivered'::public.order_status
      and oi.product_id = shop_product_reviews.product_id
  )
  and private.is_public_shop_active(shop_id)
);
drop policy if exists product_reviews_owner_update on public.shop_product_reviews;
create policy product_reviews_owner_update on public.shop_product_reviews for update to authenticated
using (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id))
with check (private.is_shop_owner(shop_id) and private.is_active_subscribed_shop(shop_id));

comment on table public.shop_storefront_settings is 'Per-shop customer storefront appearance, delivery and policy settings. Public access is restricted to authenticated customers and active shops.';
comment on table public.shop_delivery_zones is 'Per-shop serviceable six-digit pincodes and delivery charges.';
comment on table public.shop_coupons is 'Private shop-owned coupon definitions. Redemption must be validated server-side before any discount is applied.';
comment on table public.shop_product_reviews is 'Verified-purchase product reviews. Customer may review only products in their delivered order; public display requires owner approval.';
