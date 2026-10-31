create or replace function private.prevent_electronics_identifier_duplicates()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.shop_id::text,1));
 if new.imei_1 is not null and new.imei_1=new.imei_2 then raise exception 'IMEI 1 and IMEI 2 must be different' using errcode='23505'; end if;
 if new.imei_1 is not null and exists(select 1 from public.electronics_inventory e where e.shop_id=new.shop_id and e.id is distinct from new.id and (e.imei_1=new.imei_1 or e.imei_2=new.imei_1)) then raise exception 'IMEI 1 is already registered to another device in this shop' using errcode='23505'; end if;
 if new.imei_2 is not null and exists(select 1 from public.electronics_inventory e where e.shop_id=new.shop_id and e.id is distinct from new.id and (e.imei_1=new.imei_2 or e.imei_2=new.imei_2)) then raise exception 'IMEI 2 is already registered to another device in this shop' using errcode='23505'; end if;
 return new;
end;
$$;
drop trigger if exists electronics_imei_cross_column_guard on public.electronics_inventory;
create trigger electronics_imei_cross_column_guard before insert or update of shop_id,imei_1,imei_2 on public.electronics_inventory for each row execute function private.prevent_electronics_identifier_duplicates();
