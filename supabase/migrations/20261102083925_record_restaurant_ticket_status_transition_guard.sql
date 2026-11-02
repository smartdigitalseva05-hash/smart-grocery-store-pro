-- Record the existing forward-only restaurant kitchen ticket transition guard
-- in the migration history so local and remote schemas stay reproducible.
CREATE OR REPLACE FUNCTION private.guard_restaurant_ticket_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  IF (OLD.status = 'new' AND NEW.status IN ('preparing', 'cancelled'))
     OR (OLD.status = 'preparing' AND NEW.status IN ('ready', 'cancelled'))
     OR (OLD.status = 'ready' AND NEW.status IN ('served', 'cancelled')) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid restaurant ticket status transition: % -> %', OLD.status, NEW.status
    USING ERRCODE = '23514';
END;
$function$;

DROP TRIGGER IF EXISTS guard_restaurant_ticket_status_transition
  ON public.restaurant_kitchen_tickets;
CREATE TRIGGER guard_restaurant_ticket_status_transition
BEFORE UPDATE OF status ON public.restaurant_kitchen_tickets
FOR EACH ROW EXECUTE FUNCTION private.guard_restaurant_ticket_status_transition();
