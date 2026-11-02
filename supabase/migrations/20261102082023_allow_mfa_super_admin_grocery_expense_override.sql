-- Permit a verified, AAL2 Super Admin to update grocery expenses
-- while retaining immutable shop_id and created_by enforcement in the trigger.
DROP POLICY IF EXISTS grocery_expenses_update ON public.grocery_expenses;

CREATE POLICY grocery_expenses_update ON public.grocery_expenses
FOR UPDATE TO authenticated
USING (
  private.is_shop_owner(shop_id)
  AND EXISTS (
    SELECT 1
    FROM public.shops s
    WHERE s.id = grocery_expenses.shop_id
      AND s.business_type = 'grocery'
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
)
WITH CHECK (
  private.is_shop_owner(shop_id)
  AND (
    created_by = (SELECT auth.uid())
    OR private.is_super_admin()
  )
  AND EXISTS (
    SELECT 1
    FROM public.shops s
    WHERE s.id = grocery_expenses.shop_id
      AND s.business_type = 'grocery'
      AND s.is_active = true
      AND s.status = 'active'::public.shop_status
      AND s.subscription_expires_at > now()
  )
);
