-- Keep the privileged checkout implementation outside PostgREST's exposed public schema.
ALTER FUNCTION public.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) SET SCHEMA private;

CREATE OR REPLACE FUNCTION public.restaurant_pos_checkout(
 p_shop_id uuid,p_lines jsonb,p_discount numeric DEFAULT 0,p_tax_rate numeric DEFAULT 0,
 p_payment_method text DEFAULT 'cash',p_payment_status text DEFAULT 'paid',
 p_customer_name text DEFAULT NULL,p_notes text DEFAULT NULL
)
RETURNS TABLE(sale_id uuid,invoice_number text,subtotal numeric,discount_amount numeric,tax_amount numeric,total_amount numeric)
LANGUAGE sql
SECURITY INVOKER
SET search_path=''
AS $function$
 SELECT * FROM private.restaurant_pos_checkout(
  p_shop_id,p_lines,p_discount,p_tax_rate,p_payment_method,p_payment_status,p_customer_name,p_notes
 );
$function$;

GRANT USAGE ON SCHEMA private TO authenticated;
REVOKE ALL ON FUNCTION private.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.restaurant_pos_checkout(uuid,jsonb,numeric,numeric,text,text,text,text) TO authenticated;

DROP POLICY IF EXISTS restaurant_invoice_counters_deny_api ON public.restaurant_invoice_counters;
CREATE POLICY restaurant_invoice_counters_deny_api ON public.restaurant_invoice_counters
 FOR ALL TO anon,authenticated USING (false) WITH CHECK (false);

CREATE INDEX IF NOT EXISTS restaurant_sales_shop_created_idx
 ON public.restaurant_sales(shop_id,created_at DESC);
CREATE INDEX IF NOT EXISTS restaurant_sale_items_sale_idx
 ON public.restaurant_sale_items(sale_id);
CREATE INDEX IF NOT EXISTS restaurant_sale_items_menu_item_idx
 ON public.restaurant_sale_items(menu_item_id);
