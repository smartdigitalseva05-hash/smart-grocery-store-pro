DROP POLICY IF EXISTS products_historical_order_read ON public.products;

DROP POLICY IF EXISTS products_read ON public.products;
CREATE POLICY products_read
ON public.products
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = products.shop_id AND s.is_active = true
  )
  OR private.is_shop_owner(shop_id)
  OR private.is_super_admin()
  OR EXISTS (
    SELECT 1
    FROM public.order_items oi
    JOIN public.orders o ON o.id = oi.order_id
    WHERE oi.product_id = products.id
      AND o.customer_id = (SELECT auth.uid())
  )
);
