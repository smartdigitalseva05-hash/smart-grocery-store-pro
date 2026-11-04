
drop policy if exists shop_business_ledger_insert_owner on public.shop_business_ledger;
create policy shop_business_ledger_insert_owner on public.shop_business_ledger
for insert to authenticated with check (
 private.is_shop_owner(shop_business_ledger.shop_id)
 and private.is_active_subscribed_shop(shop_business_ledger.shop_id)
 and shop_business_ledger.created_by=(select auth.uid())
 and exists(select 1 from public.shops s where s.id=shop_business_ledger.shop_id and s.business_type=shop_business_ledger.business_type)
);
drop policy if exists shop_business_ledger_update_owner on public.shop_business_ledger;
create policy shop_business_ledger_update_owner on public.shop_business_ledger
for update to authenticated using (
 private.is_shop_owner(shop_business_ledger.shop_id) and private.is_active_subscribed_shop(shop_business_ledger.shop_id)
) with check (
 private.is_shop_owner(shop_business_ledger.shop_id)
 and private.is_active_subscribed_shop(shop_business_ledger.shop_id)
 and shop_business_ledger.created_by=(select auth.uid())
 and exists(select 1 from public.shops s where s.id=shop_business_ledger.shop_id and s.business_type=shop_business_ledger.business_type)
);
