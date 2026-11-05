ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_business_type_allowed;
ALTER TABLE public.shops ADD CONSTRAINT shops_business_type_allowed CHECK (business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast']::text[]));
