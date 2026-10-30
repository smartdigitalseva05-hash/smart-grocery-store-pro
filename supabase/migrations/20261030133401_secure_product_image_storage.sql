-- Restrict product image uploads to the active, subscribed owner of each shop.
-- Public reads remain available because product-images is a public bucket.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'product-images';

drop policy if exists "shopkeepers_upload_own_product_images" on storage.objects;
create policy "shopkeepers_upload_own_product_images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'product-images'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.shops s
    where s.id = ((storage.foldername(name))[1])::uuid
      and s.owner_id = (select auth.uid())
      and s.status = 'active'
      and s.is_active = true
      and s.subscription_expires_at > now()
      and private.is_shop_owner(s.id)
  )
);

drop policy if exists "shopkeepers_update_own_product_images" on storage.objects;
create policy "shopkeepers_update_own_product_images"
on storage.objects for update to authenticated
using (
  bucket_id = 'product-images'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.shops s
    where s.id = ((storage.foldername(name))[1])::uuid
      and s.owner_id = (select auth.uid())
      and s.status = 'active'
      and s.is_active = true
      and s.subscription_expires_at > now()
      and private.is_shop_owner(s.id)
  )
)
with check (
  bucket_id = 'product-images'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.shops s
    where s.id = ((storage.foldername(name))[1])::uuid
      and s.owner_id = (select auth.uid())
      and s.status = 'active'
      and s.is_active = true
      and s.subscription_expires_at > now()
      and private.is_shop_owner(s.id)
  )
);

drop policy if exists "shopkeepers_delete_own_product_images" on storage.objects;
create policy "shopkeepers_delete_own_product_images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'product-images'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.shops s
    where s.id = ((storage.foldername(name))[1])::uuid
      and s.owner_id = (select auth.uid())
      and s.status = 'active'
      and s.is_active = true
      and s.subscription_expires_at > now()
      and private.is_shop_owner(s.id)
  )
);
