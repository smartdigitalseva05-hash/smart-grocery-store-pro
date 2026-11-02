-- Record payment creation and security-relevant state changes through
-- a private trigger, without exposing direct audit-log writes to clients.
CREATE OR REPLACE FUNCTION private.audit_payment_state_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
BEGIN
  v_new := pg_catalog.jsonb_build_object(
    'user_id', NEW.user_id,
    'order_id', NEW.order_id,
    'shop_subscription_id', NEW.shop_subscription_id,
    'amount', NEW.amount,
    'currency', NEW.currency,
    'status', NEW.status,
    'gateway', NEW.gateway,
    'verified', NEW.verified,
    'actor_context', coalesce(auth.jwt() ->> 'role', 'database')
  );

  IF TG_OP = 'UPDATE' THEN
    IF OLD.user_id IS NOT DISTINCT FROM NEW.user_id
       AND OLD.order_id IS NOT DISTINCT FROM NEW.order_id
       AND OLD.shop_subscription_id IS NOT DISTINCT FROM NEW.shop_subscription_id
       AND OLD.amount IS NOT DISTINCT FROM NEW.amount
       AND OLD.currency IS NOT DISTINCT FROM NEW.currency
       AND OLD.status IS NOT DISTINCT FROM NEW.status
       AND OLD.gateway IS NOT DISTINCT FROM NEW.gateway
       AND OLD.gateway_order_id IS NOT DISTINCT FROM NEW.gateway_order_id
       AND OLD.gateway_transaction_id IS NOT DISTINCT FROM NEW.gateway_transaction_id
       AND OLD.verified IS NOT DISTINCT FROM NEW.verified THEN
      RETURN NEW;
    END IF;

    v_old := pg_catalog.jsonb_build_object(
      'user_id', OLD.user_id,
      'order_id', OLD.order_id,
      'shop_subscription_id', OLD.shop_subscription_id,
      'amount', OLD.amount,
      'currency', OLD.currency,
      'status', OLD.status,
      'gateway', OLD.gateway,
      'verified', OLD.verified
    );
  END IF;

  INSERT INTO public.audit_logs (
    actor_id, action, entity, entity_id, old_data, new_data
  )
  VALUES (
    auth.uid(),
    'payment'::public.audit_action,
    'payments',
    NEW.id,
    v_old,
    v_new
  );

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_audit_payment_state ON public.payments;
CREATE TRIGGER trg_audit_payment_state
AFTER INSERT OR UPDATE OF
  user_id, order_id, shop_subscription_id, amount, currency,
  status, gateway, gateway_order_id, gateway_transaction_id, verified
ON public.payments
FOR EACH ROW
EXECUTE FUNCTION private.audit_payment_state_changes();

REVOKE EXECUTE ON FUNCTION private.audit_payment_state_changes()
  FROM PUBLIC, anon, authenticated;
