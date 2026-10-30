
CREATE OR REPLACE FUNCTION public.owner_dashboard_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only active super_admin can access owner dashboard'
      USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'generated_at', now(),
    'customers', (SELECT count(*) FROM public.profiles WHERE role = 'customer'::public.user_role AND is_active),
    'shopkeepers', (SELECT count(*) FROM public.profiles WHERE role = 'shopkeeper'::public.user_role AND is_active),
    'shops_total', (SELECT count(*) FROM public.shops),
    'shops_active', (SELECT count(*) FROM public.shops WHERE is_active AND status = 'active'),
    'shops_pending_or_inactive', (SELECT count(*) FROM public.shops WHERE NOT is_active OR status <> 'active'),
    'products_total', (SELECT count(*) FROM public.products),
    'orders_total', (SELECT count(*) FROM public.orders),
    'orders_pending', (SELECT count(*) FROM public.orders WHERE status = 'pending'),
    'orders_delivered', (SELECT count(*) FROM public.orders WHERE status = 'delivered'),
    'payments_verified', (SELECT count(*) FROM public.payments WHERE verified),
    'verified_payment_amount_inr', (SELECT coalesce(sum(amount),0) FROM public.payments WHERE verified AND status = 'success'),
    'subscriptions_active', (SELECT count(*) FROM public.shop_subscriptions WHERE status = 'active'),
    'subscriptions_expired', (SELECT count(*) FROM public.shop_subscriptions WHERE status = 'expired')
  ) INTO result;

  RETURN result;
END;
$function$;

REVOKE ALL ON FUNCTION public.owner_dashboard_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_dashboard_summary() TO authenticated;
