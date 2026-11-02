-- The customer-credit ledger is an append-only bookkeeping journal.
-- Corrections must be recorded as compensating adjustment entries, never by
-- editing or deleting prior rows.
DROP POLICY IF EXISTS shop_credit_ledger_owner_all ON public.shop_credit_ledger;

CREATE POLICY shop_credit_ledger_owner_select ON public.shop_credit_ledger
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = shop_credit_ledger.shop_id
        AND s.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY shop_credit_ledger_owner_insert ON public.shop_credit_ledger
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = shop_credit_ledger.shop_id
        AND s.owner_id = (SELECT auth.uid())
    )
    AND created_by = (SELECT auth.uid())
  );

REVOKE UPDATE, DELETE ON TABLE public.shop_credit_ledger
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.prevent_shop_credit_ledger_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'Customer credit ledger entries are append-only; add a compensating adjustment instead'
    USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION private.prevent_shop_credit_ledger_mutation()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_prevent_shop_credit_ledger_mutation ON public.shop_credit_ledger;
CREATE TRIGGER trg_prevent_shop_credit_ledger_mutation
  BEFORE UPDATE OR DELETE ON public.shop_credit_ledger
  FOR EACH ROW EXECUTE FUNCTION private.prevent_shop_credit_ledger_mutation();

CREATE OR REPLACE FUNCTION private.audit_shop_credit_ledger_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  INSERT INTO public.audit_logs(actor_id, action, entity, entity_id, new_data)
  VALUES (
    NEW.created_by,
    'create'::public.audit_action,
    'shop_credit_ledger',
    NEW.id,
    pg_catalog.jsonb_build_object(
      'shop_id', NEW.shop_id,
      'entry_type', NEW.entry_type,
      'amount', NEW.amount,
      'entry_date', NEW.entry_date
    )
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.audit_shop_credit_ledger_insert()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_audit_shop_credit_ledger_insert ON public.shop_credit_ledger;
CREATE TRIGGER trg_audit_shop_credit_ledger_insert
  AFTER INSERT ON public.shop_credit_ledger
  FOR EACH ROW EXECUTE FUNCTION private.audit_shop_credit_ledger_insert();
