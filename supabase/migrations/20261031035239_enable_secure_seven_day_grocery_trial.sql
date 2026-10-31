create table if not exists public.shop_trials (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete restrict,
 shop_id uuid not null references public.shops(id) on delete restrict,
 status text not null default 'active' check(status in ('active','expired')),
 started_at timestamptz not null default now(),
 ends_at timestamptz not null,
 created_at timestamptz not null default now(),
 constraint shop_trials_one_per_account unique(owner_id),
 constraint shop_trials_one_per_shop unique(shop_id),
 constraint shop_trials_valid_window check(ends_at>started_at)
);
alter table public.shop_trials enable row level security;
grant select on public.shop_trials to authenticated;
drop policy if exists shop_trials_owner_or_admin_read on public.shop_trials;
create policy shop_trials_owner_or_admin_read on public.shop_trials for select to authenticated
using(owner_id=(select auth.uid()) or private.is_super_admin());
