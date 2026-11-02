-- Remove broad anonymous table-level access and expose only columns
-- actually queried by public storefront, booking and plan pages.
-- This also revokes PostgreSQL 17 MAINTAIN inherited by the anon table grants.
REVOKE ALL ON TABLE public.shops, public.products, public.categories,
  public.hotel_rooms, public.subscription_plans
  FROM PUBLIC, anon;

GRANT SELECT (id, name, city, business_type, status, is_active)
  ON TABLE public.shops TO anon;

GRANT SELECT (id, shop_id, category_id, name, description, price,
  sale_price, stock, images, is_available, created_at)
  ON TABLE public.products TO anon;

GRANT SELECT (id, name, is_active, business_type)
  ON TABLE public.categories TO anon;

GRANT SELECT (id, shop_id, room_type, capacity, base_rate, room_status, is_active)
  ON TABLE public.hotel_rooms TO anon;

GRANT SELECT (name, price_monthly, price_yearly, max_products,
  max_orders_per_month, features, is_active)
  ON TABLE public.subscription_plans TO anon;

-- These tables are currently used only by authenticated shopkeeper flows;
-- no public customer page reads them. Keep them off the anonymous API.
REVOKE ALL ON TABLE public.garment_product_variants,
  public.jewellery_product_details, public.restaurant_menu_items,
  public.restaurant_tables, public.subcategories
  FROM PUBLIC, anon;
