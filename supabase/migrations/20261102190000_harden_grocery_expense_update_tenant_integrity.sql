-- Keep grocery expense updates inside the same active Grocery shop.
-- Also make tenant and creator identity immutable for authenticated sessions.
CREATE OR REPLACE FUNCTION private.prevent_grocery_expense_identity_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL
     AND (
       NEW.shop_id IS DISTINCT FROM OLD.shop_id
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
     ) THEN
    RAISE EXCEPTION 'Expense shop and creator cannot be changed'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION private.prevent_grocery_expense_identity_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS prevent_grocery_expense_identity_change
  ON public.grocery_expenses;
CREATE TRIGGER prevent_grocery_expense_identity_change
BEFORE UPDATE OF shop_id, created_by ON public.grocery_expenses
FOR EACH ROW
EXECUTE FUNCTION private.prevent_grocery_expense_identity_change();

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
  AND created_by = (SELECT auth.uid())
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
