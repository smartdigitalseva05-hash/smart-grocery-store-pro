create table if not exists public.garment_product_variants (
 id uuid primary key default gen_random_uuid(),
 shop_id uuid not null references public.shops(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 sku text not null,
 size_label text not null,
 color_name text not null,
 price numeric not null check(price>=0),
 stock integer not null default 0 check(stock>=0),
 is_available boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint garment_variant_option_unique unique(product_id,size_label,color_name),
 constraint garment_variant_shop_sku_unique unique(shop_id,sku)
);
create index if not exists garment_variants_shop_product_idx on public.garment_product_variants(shop_id,product_id);
alter table public.garment_product_variants enable row level security;
grant select on public.garment_product_variants to anon,authenticated;
grant insert,update,delete on public.garment_product_variants to authenticated;
