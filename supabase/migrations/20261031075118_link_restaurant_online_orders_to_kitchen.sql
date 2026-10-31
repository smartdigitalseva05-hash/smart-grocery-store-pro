alter table public.restaurant_kitchen_tickets add column if not exists source_order_id uuid references public.orders(id) on delete set null;
create unique index if not exists restaurant_kitchen_tickets_source_order_uidx on public.restaurant_kitchen_tickets(source_order_id) where source_order_id is not null;
create or replace function private.create_restaurant_kitchen_ticket_from_order_item()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_order public.orders%rowtype; v_ticket_id uuid; v_item_name text;
begin
 select o.* into v_order from public.orders o join public.shops s on s.id=o.shop_id where o.id=new.order_id and s.business_type='restaurant';
 if not found then return new; end if;
 insert into public.restaurant_kitchen_tickets(shop_id,source_order_id,notes)
 values(v_order.shop_id,v_order.id,'Online order '||v_order.order_number)
 on conflict(source_order_id) where source_order_id is not null do update set updated_at=now()
 returning id into v_ticket_id;
 select p.name into v_item_name from public.products p where p.id=new.product_id and p.shop_id=v_order.shop_id;
 insert into public.restaurant_kitchen_ticket_items(ticket_id,menu_item_id,item_name,quantity,unit_price)
 values(v_ticket_id,null,coalesce(v_item_name,'Restaurant item'),new.quantity,new.price_at_purchase);
 return new;
end;
$$;
drop trigger if exists order_items_to_restaurant_kitchen on public.order_items;
create trigger order_items_to_restaurant_kitchen after insert on public.order_items for each row execute function private.create_restaurant_kitchen_ticket_from_order_item();
