ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_business_type_check;
ALTER TABLE public.categories ADD CONSTRAINT categories_business_type_check CHECK (business_type IS NULL OR business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast']::text[]));
ALTER TABLE public.shop_business_ledger DROP CONSTRAINT IF EXISTS shop_business_ledger_business_type_check;
ALTER TABLE public.shop_business_ledger ADD CONSTRAINT shop_business_ledger_business_type_check CHECK (business_type = ANY (ARRAY['grocery','daily_needs','garments','jewellery','restaurant','hotel','office_company','electronics','medical','digital_services','other','healthy_food_breakfast']::text[]));
INSERT INTO public.categories (name,slug,business_type,is_active)
VALUES
 ('Fresh Fruits','fresh-fruits','healthy_food_breakfast',true),
 ('Fruit Bowls & Salads','fruit-bowls-salads','healthy_food_breakfast',true),
 ('Fresh Juices & Smoothies','fresh-juices-smoothies','healthy_food_breakfast',true),
 ('Healthy Breakfast','healthy-breakfast','healthy_food_breakfast',true),
 ('Sprouts & Protein Bowls','sprouts-protein-bowls','healthy_food_breakfast',true),
 ('Oats, Dairy & Nuts','oats-dairy-nuts','healthy_food_breakfast',true)
ON CONFLICT (slug) DO NOTHING;
