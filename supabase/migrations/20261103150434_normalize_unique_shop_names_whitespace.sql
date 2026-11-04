
DROP INDEX IF EXISTS public.shops_name_normalized_unique_idx;
CREATE UNIQUE INDEX shops_name_normalized_unique_idx
ON public.shops (lower(regexp_replace(btrim(name), '[[:space:]]+', ' ', 'g')));
