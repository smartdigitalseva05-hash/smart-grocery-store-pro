-- Keep public hotel booking read working without granting anon execution
-- of authenticated-owner helper functions. Other internal catalog extensions
-- are not currently used by public pages and are authenticated-only.
DROP POLICY IF EXISTS hotel_rooms_read ON public.hotel_rooms;
CREATE POLICY hotel_rooms_read_public
  ON public.hotel_rooms FOR SELECT TO anon
  USING (is_active = true AND private.is_public_shop_active(shop_id));
CREATE POLICY hotel_rooms_read_authenticated
  ON public.hotel_rooms FOR SELECT TO authenticated
  USING (
    private.is_shop_owner(shop_id)
    OR private.is_super_admin()
    OR (is_active = true AND private.is_public_shop_active(shop_id))
  );

ALTER POLICY garment_variants_read
  ON public.garment_product_variants TO authenticated;
ALTER POLICY jewellery_details_read
  ON public.jewellery_product_details TO authenticated;
ALTER POLICY restaurant_menu_items_read
  ON public.restaurant_menu_items TO authenticated;
ALTER POLICY restaurant_tables_read
  ON public.restaurant_tables TO authenticated;
ALTER POLICY subcat_read
  ON public.subcategories TO authenticated;
