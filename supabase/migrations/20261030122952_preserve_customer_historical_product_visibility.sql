CREATE POLICY products_historical_order_read
ON public.products
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.order_items oi
    JOIN public.orders o ON o.id = oi.order_id
    WHERE oi.product_id = products.id
      AND o.customer_id = (SELECT auth.uid())
  )
);