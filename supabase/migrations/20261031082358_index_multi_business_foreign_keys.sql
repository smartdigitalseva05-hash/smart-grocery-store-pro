create index if not exists electronics_inventory_product_id_idx on public.electronics_inventory(product_id);
create index if not exists medical_inventory_batches_product_id_idx on public.medical_inventory_batches(product_id);
create index if not exists restaurant_kitchen_ticket_items_menu_item_id_idx on public.restaurant_kitchen_ticket_items(menu_item_id);
create index if not exists restaurant_kitchen_tickets_table_id_idx on public.restaurant_kitchen_tickets(table_id);
