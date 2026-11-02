-- Protect the three remaining anonymous INSERT endpoints (electronics
-- repair, hotel booking requests and restaurant reservations) from spam.
-- Phone identifiers are HMACed; raw phone numbers are not persisted here.
CREATE TABLE IF NOT EXISTS private.public_intake_rate_limit_key (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  secret bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.public_intake_rate_limit_key(singleton,secret)
VALUES (true,extensions.gen_random_bytes(32))
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS private.public_intake_rate_limit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  request_type text NOT NULL CHECK (request_type IN ('electronics_repair','hotel_booking','restaurant_reservation')),
  scope text NOT NULL CHECK (scope IN ('phone','shop')),
  subject_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS public_intake_rate_limit_events_lookup_idx
  ON private.public_intake_rate_limit_events(shop_id,request_type,scope,subject_hash,created_at DESC);
CREATE INDEX IF NOT EXISTS public_intake_rate_limit_events_created_idx
  ON private.public_intake_rate_limit_events(created_at);

ALTER TABLE private.public_intake_rate_limit_key ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.public_intake_rate_limit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.public_intake_rate_limit_key
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON TABLE private.public_intake_rate_limit_events
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE private.public_intake_rate_limit_events_id_seq
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.consume_public_intake_rate_limit(
  p_request_type text,
  p_shop_id uuid,
  p_applicant_phone text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_secret bytea;
  v_phone text;
  v_phone_hash bytea;
  v_shop_hash bytea;
  v_now timestamptz := pg_catalog.now();
  v_count integer;
BEGIN
  IF p_request_type NOT IN ('electronics_repair','hotel_booking','restaurant_reservation')
     OR p_shop_id IS NULL THEN
    RAISE EXCEPTION 'Invalid public intake rate-limit scope' USING ERRCODE='22023';
  END IF;

  v_phone := pg_catalog.regexp_replace(coalesce(p_applicant_phone,''),'[^0-9]','','g');
  IF pg_catalog.char_length(v_phone) NOT BETWEEN 7 AND 15 THEN
    RAISE EXCEPTION 'A valid contact phone is required' USING ERRCODE='22023';
  END IF;

  SELECT secret INTO STRICT v_secret
  FROM private.public_intake_rate_limit_key WHERE singleton=true;

  v_phone_hash := extensions.hmac(
    pg_catalog.convert_to('phone:'||v_phone,'UTF8'),v_secret,'sha256'
  );
  v_shop_hash := extensions.hmac(
    pg_catalog.convert_to('shop:'||p_shop_id::text,'UTF8'),v_secret,'sha256'
  );

  -- Acquire locks in the same order for every request to avoid deadlocks.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'public-intake:'||p_request_type||':phone:'||p_shop_id::text||':'||pg_catalog.encode(v_phone_hash,'hex'),0
    )
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('public-intake:'||p_request_type||':shop:'||p_shop_id::text,0)
  );

  DELETE FROM private.public_intake_rate_limit_events
  WHERE created_at < v_now - interval '7 days';

  SELECT count(*)::integer INTO v_count
  FROM private.public_intake_rate_limit_events
  WHERE shop_id=p_shop_id AND request_type=p_request_type
    AND scope='phone' AND subject_hash=v_phone_hash
    AND created_at > v_now - interval '1 hour';
  IF v_count >= 5 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE='Too many requests from this phone number. Please try again later.',
            DETAIL='Maximum 5 requests per phone number per shop in any rolling 60-minute window.';
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM private.public_intake_rate_limit_events
  WHERE shop_id=p_shop_id AND request_type=p_request_type
    AND scope='shop' AND subject_hash=v_shop_hash
    AND created_at > v_now - interval '1 hour';
  IF v_count >= 120 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE='This business is temporarily receiving too many requests. Please try again later.',
            DETAIL='Maximum 120 requests per shop and request type in any rolling 60-minute window.';
  END IF;

  INSERT INTO private.public_intake_rate_limit_events(shop_id,request_type,scope,subject_hash,created_at)
  VALUES
    (p_shop_id,p_request_type,'phone',v_phone_hash,v_now),
    (p_shop_id,p_request_type,'shop',v_shop_hash,v_now);
END;
$function$;

CREATE OR REPLACE FUNCTION private.enforce_public_intake_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM private.consume_public_intake_rate_limit(
    TG_ARGV[0],
    NEW.shop_id,
    pg_catalog.to_jsonb(NEW)->>TG_ARGV[1]
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.consume_public_intake_rate_limit(text,uuid,text)
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION private.enforce_public_intake_rate_limit()
  FROM PUBLIC,anon,authenticated,service_role;

DROP TRIGGER IF EXISTS trg_limit_electronics_service_job_intake ON public.electronics_service_jobs;
CREATE TRIGGER trg_limit_electronics_service_job_intake
  BEFORE INSERT ON public.electronics_service_jobs
  FOR EACH ROW EXECUTE FUNCTION private.enforce_public_intake_rate_limit('electronics_repair','customer_phone');

DROP TRIGGER IF EXISTS trg_limit_hotel_booking_request_intake ON public.hotel_booking_requests;
CREATE TRIGGER trg_limit_hotel_booking_request_intake
  BEFORE INSERT ON public.hotel_booking_requests
  FOR EACH ROW EXECUTE FUNCTION private.enforce_public_intake_rate_limit('hotel_booking','guest_phone');

DROP TRIGGER IF EXISTS trg_limit_restaurant_reservation_intake ON public.restaurant_reservations;
CREATE TRIGGER trg_limit_restaurant_reservation_intake
  BEFORE INSERT ON public.restaurant_reservations
  FOR EACH ROW EXECUTE FUNCTION private.enforce_public_intake_rate_limit('restaurant_reservation','customer_phone');
