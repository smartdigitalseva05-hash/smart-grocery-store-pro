
begin;
update public.subscription_plans
set price_monthly = case slug
  when 'basic' then 99
  when 'pro' then 199
  when 'enterprise' then 299
  else price_monthly
end,
price_yearly = case slug
  when 'basic' then 990
  when 'pro' then 1990
  when 'enterprise' then 2990
  else price_yearly
end
where slug in ('basic','pro','enterprise');
commit;
