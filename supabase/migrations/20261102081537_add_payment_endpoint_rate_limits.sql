-- Account-scoped rolling-window limits for sensitive Razorpay endpoints.
CREATE TABLE private.payment_endpoint_rate_limit_events (
  user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('checkout','verify')),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX payment_endpoint_rate_limit_lookup_idx
  ON private.payment_endpoint_rate_limit_events (user_id, action, created_at DESC);

ALTER TABLE private.payment_endpoint_rate_limit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.payment_endpoint_rate_limit_events
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.consume_payment_endpoint_rate_limit(
  p_user_id uuid,
  p_action text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_now timestamptz := pg_catalog.now();
  v_count integer;
  v_limit integer;
BEGIN
  IF p_user_id IS NULL OR p_action NOT IN ('checkout','verify') THEN
    RAISE EXCEPTION 'Invalid payment rate-limit scope' USING ERRCODE='22023';
  END IF;

  v_limit := CASE p_action WHEN 'checkout' THEN 5 WHEN 'verify' THEN 10 END;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('payment-endpoint:'||p_action||':'||p_user_id::text,0)
  );

  DELETE FROM private.payment_endpoint_rate_limit_events
  WHERE created_at < v_now - interval '24 hours';

  SELECT count(*)::integer INTO v_count
  FROM private.payment_endpoint_rate_limit_events
  WHERE user_id=p_user_id
    AND action=p_action
    AND created_at > v_now - interval '15 minutes';

  IF v_count >= v_limit THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE='Too many payment requests. Please wait 15 minutes and try again.',
            DETAIL='Payment endpoint account limit exceeded for a rolling 15-minute window.';
  END IF;

  INSERT INTO private.payment_endpoint_rate_limit_events(user_id,action,created_at)
  VALUES(p_user_id,p_action,v_now);
END;
$function$;

REVOKE EXECUTE ON FUNCTION private.consume_payment_endpoint_rate_limit(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT EXECUTE ON FUNCTION private.consume_payment_endpoint_rate_limit(uuid,text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.consume_payment_endpoint_rate_limit(
  p_user_id uuid,
  p_action text
)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT private.consume_payment_endpoint_rate_limit(p_user_id,p_action);
$function$;

REVOKE EXECUTE ON FUNCTION public.consume_payment_endpoint_rate_limit(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_payment_endpoint_rate_limit(uuid,text)
  TO service_role;
