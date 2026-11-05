-- Restaurant POS: shop-scoped sales, invoice snapshots and server-priced checkout.
CREATE TABLE IF NOT EXISTS public.restaurant_sales (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
 invoice_number text NOT NULL,
 customer_name text,
 subtotal numeric(12,2) NOT NULL CHECK (subtotal >= 0),
 discount_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
 tax_rate numeric(5,2) NOT NULL DEFAULT 0 CHECK (tax_rate BETWEEN 0 AND 100),
 tax_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
 total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
 payment_method text NOT NULL CHECK (payment_method IN ('cash','upi','card','other')),
 payment_status text NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid','unpaid')),
 notes text,
 created_by uuid NOT NULL DEFAULT auth.uid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(shop_id,invoice_number)
);
CREATE TABLE IF NOT EXISTS public.restaurant_sale_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 sale_id uuid NOT NULL REFERENCES public.restaurant_sales(id) ON DELETE CASCADE,
 menu_item_id uuid REFERENCES public.restaurant_menu_items(id) ON DELETE SET NULL,
 item_name text NOT NULL,
 quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 999),
 unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
 line_total numeric(12,2) NOT NULL CHECK (line_total >= 0),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.restaurant_invoice_counters (
 shop_id uuid PRIMARY KEY REFERENCES public.shops(id) ON DELETE CASCADE,
 last_number bigint NOT NULL DEFAULT 0 CHECK (last_number >= 0)
);
ALTER TABLE public.restaurant_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_invoice_counters ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS restaurant_sales_owner_read ON public.restaurant_sales;
CREATE POLICY restaurant_sales_owner_read ON public.restaurant_sales FOR SELECT TO authenticated
 USING (private.is_shop_owner(shop_id) OR private.is_super_admin());
DROP POLICY IF EXISTS restaurant_sale_items_owner_read ON public.restaurant_sale_items;
CREATE POLICY restaurant_sale_items_owner_read ON public.restaurant_sale_items FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.restaurant_sales s WHERE s.id=restaurant_sale_items.sale_id AND (private.is_shop_owner(s.shop_id) OR private.is_super_admin())));
REVOKE ALL ON public.restaurant_sales,public.restaurant_sale_items,public.restaurant_invoice_counters FROM anon,authenticated;
GRANT SELECT ON public.restaurant_sales,public.restaurant_sale_items TO authenticated;

CREATE OR REPLACE FUNCTION public.restaurant_pos_checkout(
 p_shop_id uuid,p_lines jsonb,p_discount numeric DEFAULT 0,p_tax_rate numeric DEFAULT 0,
 p_payment_method text DEFAULT 'cash',p_payment_status text DEFAULT 'paid',
 p_customer_name text DEFAULT NULL,p_notes text DEFAULT NULL
)
RETURNS TABLE(sale_id uuid,invoice_number text,subtotal numeric,discount_amount numeric,tax_amount numeric,total_amount numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
 v_subtotal numeric(12,2); v_discount numeric(12,2); v_tax_rate numeric(5,2);
 v_tax numeric(12,2); v_total numeric(12,2); v_invoice bigint;
 v_sale_id uuid; v_invoice_number text;
BEGIN
 IF auth.uid() IS NULL OR NOT private.is_shop_owner(p_shop_id) OR NOT private.is_active_subscribed_shop(p_shop_id) THEN
  RAISE EXCEPTION 'An active subscribed shopkeeper session is required.' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.shops s WHERE s.id=p_shop_id AND s.business_type='restaurant' AND s.is_active AND s.status='active') THEN
  RAISE EXCEPTION 'This POS is available only for an active restaurant shop.';
 END IF;
 IF jsonb_typeof(p_lines) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lines)<1 OR jsonb_array_length(p_lines)>100 THEN
  RAISE EXCEPTION 'Add between 1 and 100 order lines.';
 END IF;
 IF p_discount IS NULL OR p_discount<0 OR p_discount>100000000 OR p_tax_rate IS NULL OR p_tax_rate<0 OR p_tax_rate>100 THEN
  RAISE EXCEPTION 'Invalid discount or tax rate.';
 END IF;
 IF p_payment_method NOT IN ('cash','upi','card','other') OR p_payment_status NOT IN ('paid','unpaid') THEN
  RAISE EXCEPTION 'Invalid payment method or payment status.';
 END IF;
 IF (p_customer_name IS NOT NULL AND length(p_customer_name)>120) OR (p_notes IS NOT NULL AND length(p_notes)>500) THEN
  RAISE EXCEPTION 'Customer name or notes exceed the allowed length.';
 END IF;
 IF EXISTS(
  SELECT 1 FROM jsonb_array_elements(p_lines) x
  WHERE x->>'menu_item_id' IS NULL
    OR jsonb_typeof(x->'quantity') IS DISTINCT FROM 'number'
    OR CASE WHEN jsonb_typeof(x->'quantity')='number'
       THEN (x->>'quantity')::numeric<1 OR (x->>'quantity')::numeric>999 OR trunc((x->>'quantity')::numeric)<>(x->>'quantity')::numeric
       ELSE true END
 ) THEN RAISE EXCEPTION 'Each line needs a menu item and a whole-number quantity from 1 to 999.'; END IF;
 IF EXISTS(
  SELECT 1 FROM jsonb_array_elements(p_lines) x
  LEFT JOIN public.restaurant_menu_items m ON m.id=(x->>'menu_item_id')::uuid AND m.shop_id=p_shop_id AND m.is_available
  WHERE m.id IS NULL
 ) THEN RAISE EXCEPTION 'A selected menu item is unavailable or belongs to another shop.'; END IF;
 SELECT round(sum(m.price*(x->>'quantity')::integer),2) INTO v_subtotal
 FROM jsonb_array_elements(p_lines) x JOIN public.restaurant_menu_items m
 ON m.id=(x->>'menu_item_id')::uuid AND m.shop_id=p_shop_id AND m.is_available;
 v_discount:=round(p_discount,2);
 IF v_discount>v_subtotal THEN RAISE EXCEPTION 'Discount cannot exceed subtotal.'; END IF;
 v_tax_rate:=p_tax_rate; v_tax:=round((v_subtotal-v_discount)*v_tax_rate/100,2); v_total:=round(v_subtotal-v_discount+v_tax,2);
 INSERT INTO public.restaurant_invoice_counters(shop_id,last_number) VALUES(p_shop_id,1)
 ON CONFLICT(shop_id) DO UPDATE SET last_number=public.restaurant_invoice_counters.last_number+1 RETURNING last_number INTO v_invoice;
 v_invoice_number:='R-'||to_char(pg_catalog.now() AT TIME ZONE 'UTC','YYYYMMDD')||'-'||lpad(v_invoice::text,6,'0');
 INSERT INTO public.restaurant_sales(shop_id,invoice_number,customer_name,subtotal,discount_amount,tax_rate,tax_amount,total_amount,payment_method,payment_status,notes,created_by)
 VALUES(p_shop_id,v_invoice_number,nullif(pg_catalog.btrim(p_customer_name),''),v_subtotal,v_discount,v_tax_rate,v_tax,v_total,p_payment_method,p_payment_status,nullif(pg_catalog.btrim(p_notes),''),auth.uid())
 RETURNING id INTO v_sale_id;
 INSERT INTO public.restaurant_sale_items(sale_id,menu_item_id,item_name,quantity,unit_price,line_total)
 SELECT v_sale_id,m.id,m.name,(x->>'quantity')::integer,m.price,round(m.price*(x->>'quantity')::integer,2)
 FROM jsonb_array_elements(p_lines) x JOIN public.restaurant_menu_items m
 ON m.id=(x->>'menu_item_id')::uuid AND m.shop_id=p_shop_id AND m.is_available;
 RETURN QUERY SELECT v_sale_id,v_invoice_number,v_subtotal,v_discount,v_tax,v_total;
END;
$function$;
REVOKE ALL ON FUNCTION public.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) TO authenticated;
