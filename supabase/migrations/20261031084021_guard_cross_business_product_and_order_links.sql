create or replace function private.guard_product_reference_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare linked_shop uuid;
begin
  if new.product_id is not null then
    select shop_id into linked_shop
    from public.products
    where id = new.product_id;

    if linked_shop is not null and linked_shop is distinct from new.shop_id then
      raise exception 'Referenced product must belong to the same business'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_garment_variant_product_shop on public.garment_product_variants;
create trigger guard_garment_variant_product_shop
before insert or update of shop_id, product_id on public.garment_product_variants
for each row execute function private.guard_product_reference_shop();

drop trigger if exists guard_jewellery_detail_product_shop on public.jewellery_product_details;
create trigger guard_jewellery_detail_product_shop
before insert or update of shop_id, product_id on public.jewellery_product_details
for each row execute function private.guard_product_reference_shop();

drop trigger if exists guard_electronics_inventory_product_shop on public.electronics_inventory;
create trigger guard_electronics_inventory_product_shop
before insert or update of shop_id, product_id on public.electronics_inventory
for each row execute function private.guard_product_reference_shop();

drop trigger if exists guard_medical_batch_product_shop on public.medical_inventory_batches;
create trigger guard_medical_batch_product_shop
before insert or update of shop_id, product_id on public.medical_inventory_batches
for each row execute function private.guard_product_reference_shop();

create or replace function private.guard_restaurant_ticket_table_shop()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare linked_shop uuid;
begin
  if new.table_id is not null then
    select shop_id into linked_shop from public.restaurant_tables where id = new.table_id;
    if linked_shop is not null and linked_shop is distinct from new.shop_id then
      raise exception 'Restaurant table must belong to the same business'
        using errcode = '23514';
    end if;
  end if;

  if new.source_order_id is not null then
    select shop_id into linked_shop from public.orders where id = new.source_order_id;
    if linked_shop is not null and linked_shop is distinct from new.shop_id then
      raise exception 'Source order must belong to the same business'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
