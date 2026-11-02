-- Historical credit entries remain readable by their owning shop, but new
-- bookkeeping entries require an active Grocery shop and active shopkeeper.
DROP POLICY IF EXISTS shop_credit_ledger_owner_insert ON public.shop_credit_ledger;

CREATE POLICY shop_credit_ledger_owner_insert ON public.shop_credit_ledger
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.shops s
      JOIN public.profiles p ON p.id = s.owner_id
      WHERE s.id = shop_credit_ledger.shop_id
        AND s.owner_id = (SELECT auth.uid())
        AND s.business_type = 'grocery'
        AND s.is_active = true
        AND s.status = 'active'::public.shop_status
        AND s.subscription_expires_at > now()
        AND p.role = 'shopkeeper'::public.user_role
        AND p.is_active = true
    )
  );
