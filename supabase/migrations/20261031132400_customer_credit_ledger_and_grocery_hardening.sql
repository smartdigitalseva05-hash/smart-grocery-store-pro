-- Source-controlled reconciliation for the already-applied customer credit ledger
-- and grocery database hardening. This migration is intentionally idempotent.
CREATE TABLE IF NOT EXISTS public.shop_credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  customer_name text NOT NULL CHECK (length(trim(customer_name)) BETWEEN 1 AND 120),
  customer_phone text CHECK (customer_phone IS NULL OR length(customer_phone) <= 30),
  entry_type text NOT NULL CHECK (entry_type IN ('credit_sale','payment_received','adjustment')),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  notes text CHECK (notes IS NULL OR length(notes) <= 500),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS shop_credit_ledger_shop_date_idx
  ON public.shop_credit_ledger(shop_id, entry_date DESC, created_at DESC);
ALTER TABLE public.shop_credit_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shop_credit_ledger_owner_all ON public.shop_credit_ledger;
CREATE POLICY shop_credit_ledger_owner_all ON public.shop_credit_ledger
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.shops s
    WHERE s.id = shop_credit_ledger.shop_id
      AND s.owner_id = (SELECT auth.uid())
  ))
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = shop_credit_ledger.shop_id
        AND s.owner_id = (SELECT auth.uid())
    )
    AND created_by = (SELECT auth.uid())
  );
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shop_credit_ledger TO authenticated;

-- Index purchase foreign keys used by joins and referential checks.
CREATE INDEX IF NOT EXISTS grocery_purchases_product_id_idx
  ON public.grocery_stock_purchases(product_id);
CREATE INDEX IF NOT EXISTS grocery_purchases_supplier_id_idx
  ON public.grocery_stock_purchases(supplier_id);

-- A purchase must be recorded through the validated atomic RPC, not anonymous access.
REVOKE EXECUTE ON FUNCTION public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grocery_record_purchase(uuid,uuid,uuid,integer,numeric,text,date,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_approve_shop_application(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_approve_shop_application(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_set_shop_status(uuid, public.shop_status) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_set_shop_status(uuid, public.shop_status) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_set_shopkeeper_status(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_set_shopkeeper_status(uuid, boolean) TO authenticated;

-- Keep expense write policies owner-scoped and evaluate auth.uid() once per statement.
DROP POLICY IF EXISTS grocery_expenses_insert ON public.grocery_expenses;
CREATE POLICY grocery_expenses_insert ON public.grocery_expenses
  FOR INSERT TO authenticated
  WITH CHECK (
    private.is_shop_owner(shop_id)
    AND created_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = grocery_expenses.shop_id
        AND s.business_type = 'grocery'
        AND s.is_active = true
        AND s.status = 'active'
        AND s.subscription_expires_at > now()
    )
  );
DROP POLICY IF EXISTS grocery_expenses_update ON public.grocery_expenses;
CREATE POLICY grocery_expenses_update ON public.grocery_expenses
  FOR UPDATE TO authenticated
  USING (
    private.is_shop_owner(shop_id)
    AND EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = grocery_expenses.shop_id
        AND s.business_type = 'grocery'
        AND s.is_active = true
        AND s.status = 'active'
        AND s.subscription_expires_at > now()
    )
  )
  WITH CHECK (
    private.is_shop_owner(shop_id)
    AND created_by = (SELECT auth.uid())
  );
