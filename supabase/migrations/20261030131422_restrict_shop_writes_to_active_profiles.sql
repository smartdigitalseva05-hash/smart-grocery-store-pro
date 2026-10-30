DROP POLICY IF EXISTS shops_insert ON public.shops;
CREATE POLICY shops_insert
ON public.shops
FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.is_active = true
  )
);

DROP POLICY IF EXISTS shops_update ON public.shops;
CREATE POLICY shops_update
ON public.shops
FOR UPDATE
TO authenticated
USING (
  private.is_super_admin()
  OR (
    owner_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = 'shopkeeper'::public.user_role
        AND p.is_active = true
    )
  )
)
WITH CHECK (
  private.is_super_admin()
  OR (
    owner_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = 'shopkeeper'::public.user_role
        AND p.is_active = true
    )
  )
);
