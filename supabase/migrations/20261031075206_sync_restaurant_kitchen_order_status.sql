create or replace function private.cancel_restaurant_kitchen_ticket_for_cancelled_order()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_kitchen_status text;
begin
 if new.status is not distinct from old.status then return new; end if;
 v_kitchen_status:=case new.status when 'processing' then 'preparing' when 'out_for_delivery' then 'ready' when 'delivered' then 'served' when 'cancelled' then 'cancelled' when 'refunded' then 'cancelled' else null end;
 if v_kitchen_status is not null then
  update public.restaurant_kitchen_tickets set status=v_kitchen_status,updated_at=now()
  where source_order_id=new.id and (status<>'cancelled' or v_kitchen_status='cancelled');
 end if;
 return new;
end;
$$;
drop trigger if exists cancelled_order_to_restaurant_kitchen on public.orders;
create trigger cancelled_order_to_restaurant_kitchen after update of status on public.orders for each row execute function private.cancel_restaurant_kitchen_ticket_for_cancelled_order();
