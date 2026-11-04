
alter table public.shop_advanced_records drop constraint if exists shop_advanced_records_record_type_check;
alter table public.shop_advanced_records add constraint shop_advanced_records_record_type_check
check (record_type in (
'quotation','invoice','sales_return','purchase_return','delivery',
'appointment','customer_follow_up','loyalty_entry','warranty_claim',
'stock_adjustment','service_job','task','purchase_order','booking',
'inventory_transfer','maintenance','employee_advance','expense_claim'
));
