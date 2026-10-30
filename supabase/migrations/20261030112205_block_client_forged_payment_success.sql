
create or replace function public.prevent_payment_tamper()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_trusted boolean :=
    public.is_super_admin()
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
begin
  if v_trusted then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null
       or new.user_id is distinct from auth.uid()
       or new.verified is distinct from false
       or new.status is distinct from 'pending'::public.payment_status
       or new.amount is null
       or new.amount <= 0
       or new.currency is distinct from 'INR'
       or ((new.order_id is null) = (new.shop_subscription_id is null)) then
      raise exception 'Client may only create its own positive INR pending payment for exactly one order or subscription'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if old.user_id is distinct from new.user_id
     or old.order_id is distinct from new.order_id
     or old.shop_subscription_id is distinct from new.shop_subscription_id
     or old.amount is distinct from new.amount
     or old.currency is distinct from new.currency
     or old.status is distinct from new.status
     or old.verified is distinct from new.verified
     or old.gateway is distinct from new.gateway
     or old.gateway_transaction_id is distinct from new.gateway_transaction_id
     or old.gateway_payload is distinct from new.gateway_payload then
    raise exception 'Payment records can only be changed by the trusted payment process or active Super Admin'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_payment_tamper() from public, anon, authenticated;
