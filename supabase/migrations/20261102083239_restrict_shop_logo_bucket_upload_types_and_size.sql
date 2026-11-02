-- Bound uploads to the public shop-logo bucket to raster image formats only.
-- No existing objects were present in this bucket when this migration was applied.
UPDATE storage.buckets
SET file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp']
WHERE id = 'shop-logos';
