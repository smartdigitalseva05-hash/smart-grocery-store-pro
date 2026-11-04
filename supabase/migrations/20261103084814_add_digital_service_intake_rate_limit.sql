
CREATE OR REPLACE FUNCTION private.enforce_digital_service_intake_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.consume_digital_service_intake_limit(
    NEW.shop_id,
    NEW.applicant_phone
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_digital_service_intake_rate_limit() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_limit_digital_service_application_intake
ON public.digital_service_applications;

CREATE TRIGGER trg_limit_digital_service_application_intake
BEFORE INSERT ON public.digital_service_applications
FOR EACH ROW
EXECUTE FUNCTION private.enforce_digital_service_intake_rate_limit();
