alter table public.shop_trials drop constraint if exists shop_trials_status_check;
alter table public.shop_trials add constraint shop_trials_status_check check(status in ('active','expired','converted'));
