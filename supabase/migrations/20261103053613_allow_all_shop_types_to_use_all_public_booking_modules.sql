
create or replace function private.is_active_restaurant_booking_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.shops s
    join public.profiles p on p.id = s.owner_id
    where s.id = p_shop_id
      and s.is_active = true
      and s.status = 'active'::public.shop_status
      and s.subscription_expires_at > pg_catalog.now()
      and p.role = 'shopkeeper'::public.user_role
      and p.is_active = true
  );
$$;

create or replace function private.is_active_hotel_booking_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.shops s
    join public.profiles p on p.id = s.owner_id
    where s.id = p_shop_id
      and s.is_active = true
      and s.status = 'active'::public.shop_status
      and s.subscription_expires_at > pg_catalog.now()
      and p.role = 'shopkeeper'::public.user_role
      and p.is_active = true
  );
$$;

create or replace function private.is_active_electronics_service_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.shops s
    join public.profiles p on p.id = s.owner_id
    where s.id = p_shop_id
      and s.is_active = true
      and s.status = 'active'::public.shop_status
      and s.subscription_expires_at > pg_catalog.now()
      and p.role = 'shopkeeper'::public.user_role
      and p.is_active = true
  );
$$;
