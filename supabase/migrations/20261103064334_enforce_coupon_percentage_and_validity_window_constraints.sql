do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.shop_coupons'::regclass
      and conname='shop_coupons_percentage_at_most_100'
  ) then
    alter table public.shop_coupons
      add constraint shop_coupons_percentage_at_most_100
      check (discount_type <> 'percentage' or discount_value <= 100);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.shop_coupons'::regclass
      and conname='shop_coupons_valid_date_window'
  ) then
    alter table public.shop_coupons
      add constraint shop_coupons_valid_date_window
      check (starts_at is null or ends_at is null or ends_at > starts_at);
  end if;
end $$;