-- Keep the order audit trigger privileged but outside the exposed API schema.
CREATE OR REPLACE FUNCTION private.audit_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_reason text;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT public.validate_status_transition(OLD.status, NEW.status) THEN
      RAISE EXCEPTION 'Invalid transition % -> %', OLD.status, NEW.status;
    END IF;

    v_reason := nullif(
      left(coalesce(pg_catalog.current_setting('app.order_status_reason', true), ''), 500),
      ''
    );

    INSERT INTO public.audit_logs (
      actor_id, action, entity, entity_id, old_data, new_data
    )
    VALUES (
      auth.uid(), 'order_status', 'orders', NEW.id,
      pg_catalog.jsonb_build_object('old', OLD.status),
      pg_catalog.jsonb_build_object('new', NEW.status, 'reason', v_reason)
    );

    INSERT INTO public.order_status_history (
      order_id, old_status, new_status, changed_by, reason
    )
    VALUES (
      NEW.id, OLD.status, NEW.status, auth.uid(), v_reason
    );
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_audit_order ON public.orders;
CREATE TRIGGER trg_audit_order
BEFORE UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.audit_order_status();

REVOKE EXECUTE ON FUNCTION private.audit_order_status()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.audit_order_status()
  FROM PUBLIC, anon, authenticated;
DROP FUNCTION public.audit_order_status();
