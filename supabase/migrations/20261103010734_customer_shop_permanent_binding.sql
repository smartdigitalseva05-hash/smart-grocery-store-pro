
alter table public.profiles
  add column if not exists connected_shop_id uuid
  references public.shops(id) on delete restrict;

create index if not exists profiles_connected_shop_id_idx
  on public.profiles (connected_shop_id)
  where connected_shop_id is not null;

comment on column public.profiles.connected_shop_id is
  'The one shop this customer account permanently joined through that shopkeeper''s QR or store link.';

create or replace function private.enforce_customer_shop_binding()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.connected_shop_id is not null
     and new.connected_shop_id is distinct from old.connected_shop_id then
    raise exception using
      errcode = '23514',
      message = 'This customer account is permanently connected to its original shop.';
  end if;

  if old.connected_shop_id is null and new.connected_shop_id is not null then
    if new.role <> 'customer' then
      raise exception using
        errcode = '42501',
        message = 'Only customer accounts can connect to a shop.';
    end if;

    if auth.uid() is null or auth.uid() <> new.id then
      raise exception using
        errcode = '42501',
        message = 'Customers can connect only their own account.';
    end if;

    if not exists (
      select 1
      from public.shops s
      where s.id = new.connected_shop_id
        and s.is_active = true
        and s.status = 'active'
        and s.subscription_expires_at > now()
    ) then
      raise exception using
        errcode = '23514',
        message = 'This shop is not active and cannot accept customer connections.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_customer_shop_binding on public.profiles;
create trigger trg_enforce_customer_shop_binding
before update of connected_shop_id on public.profiles
for each row
execute function private.enforce_customer_shop_binding();
