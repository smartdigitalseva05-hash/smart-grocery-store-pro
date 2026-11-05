-- Add a dedicated, multi-trade Repair Services business category while reusing
-- the existing shop-scoped repair-job workflow and preserving existing records.
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_business_type_allowed;
ALTER TABLE public.shops ADD CONSTRAINT shops_business_type_allowed
 CHECK (business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast','repair_services']::text[]));

ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_business_type_check;
ALTER TABLE public.categories ADD CONSTRAINT categories_business_type_check
 CHECK (business_type IS NULL OR business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast','repair_services']::text[]));

ALTER TABLE public.shop_business_ledger DROP CONSTRAINT IF EXISTS shop_business_ledger_business_type_check;
ALTER TABLE public.shop_business_ledger ADD CONSTRAINT shop_business_ledger_business_type_check
 CHECK (business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast','repair_services']::text[]));

ALTER TABLE public.electronics_service_jobs
 ADD COLUMN IF NOT EXISTS service_category text NOT NULL DEFAULT 'electronics_device';

ALTER TABLE public.electronics_service_jobs
 DROP CONSTRAINT IF EXISTS electronics_service_jobs_service_category_check;
ALTER TABLE public.electronics_service_jobs
 ADD CONSTRAINT electronics_service_jobs_service_category_check
 CHECK (service_category = ANY (ARRAY[
  'electronics_device','smartphone','computer_laptop','tablet','tv_led','air_conditioner',
  'refrigerator','washing_machine','microwave_oven','printer_scanner','cctv_security',
  'inverter_ups_battery','home_appliance','audio_device','camera','gaming_console',
  'bike_scooter','car_auto','bicycle','plumbing','electrical','carpentry_furniture',
  'ro_water_purifier','solar_generator','other_repair'
 ]::text[]));

GRANT INSERT(service_category), SELECT(service_category)
 ON public.electronics_service_jobs TO authenticated;
GRANT INSERT(service_category) ON public.electronics_service_jobs TO anon;

CREATE INDEX IF NOT EXISTS electronics_service_jobs_shop_category_created_idx
 ON public.electronics_service_jobs(shop_id, service_category, created_at DESC);

CREATE OR REPLACE FUNCTION private.is_active_electronics_service_shop(p_shop_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
 SELECT EXISTS (
  SELECT 1
  FROM public.shops s
  JOIN public.profiles p ON p.id = s.owner_id
  WHERE s.id = p_shop_id
    AND s.business_type IN ('electronics','repair_services')
    AND s.is_active = true
    AND s.status = 'active'::public.shop_status
    AND s.subscription_expires_at > pg_catalog.now()
    AND p.role = 'shopkeeper'::public.user_role
    AND p.is_active = true
 );
$function$;
