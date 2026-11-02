-- Restore only the exact client table privileges used by shopkeeper.html.
-- RLS policies continue to scope every row by shop ownership and active status.
GRANT SELECT, INSERT ON TABLE public.grocery_suppliers TO authenticated;
GRANT SELECT, INSERT ON TABLE public.grocery_expenses TO authenticated;
GRANT SELECT ON TABLE public.grocery_stock_purchases, public.grocery_stock_movements TO authenticated;

-- These screens have no supplier/expense edit or delete workflow. Remove the
-- unused policies as well as withholding the corresponding table privileges.
DROP POLICY IF EXISTS grocery_suppliers_update ON public.grocery_suppliers;
DROP POLICY IF EXISTS grocery_suppliers_delete ON public.grocery_suppliers;
DROP POLICY IF EXISTS grocery_expenses_update ON public.grocery_expenses;
DROP POLICY IF EXISTS grocery_expenses_delete ON public.grocery_expenses;
