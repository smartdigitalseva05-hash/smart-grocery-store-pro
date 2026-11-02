-- Atomic rolling-window abuse limits for the anonymous digital-service
-- intake endpoint. Phone identifiers are HMACed; raw phone numbers are not
-- copied into the private rate-limit table.
CREATE TABLE IF NOT EXISTS private.digital_service_intake_rate_limit_key (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  secret bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.digital_service_intake_rate_limit_key (singleton, secret)
VALUES (true, extensions.gen_random_bytes(32))
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS private.digital_service_intake_rate_limits (
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  subject_hash bytea NOT NULL,
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL CHECK (request_count > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (shop_id, subject_hash)
);
CREATE INDEX IF NOT EXISTS digital_service_intake_rate_limits_updated_idx
  ON private.digital_service_intake_rate_limits (updated_at);

ALTER TABLE private.digital_service_intake_rate_limit_key ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.digital_service_intake_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.digital_service_intake_rate_limit_key
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE private.digital_service_intake_rate_limits
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.consume_digital_service_intake_limit(
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
  v_phone_hash bytea;
  v_shop_hash bytea;
  v_phone text;
  v_now timestamptz := pg_catalog.now();
  v_count integer;
BEGIN
  v_phone := pg_catalog.regexp_replace(p_applicant_phone, '[^0-9]', '', 'g');
  SELECT secret INTO STRICT v_secret
  FROM private.digital_service_intake_rate_limit_key
  WHERE singleton = true;

  v_phone_hash := extensions.hmac(
    pg_catalog.convert_to('phone:' || v_phone, 'UTF8'), v_secret, 'sha256'
  );
  v_shop_hash := extensions.hmac(
    pg_catalog.convert_to('shop:' || p_shop_id::text, 'UTF8'), v_secret, 'sha256'
  );

  DELETE FROM private.digital_service_intake_rate_limits
  WHERE updated_at < v_now - interval '7 days';

  INSERT INTO private.digital_service_intake_rate_limits
    (shop_id, subject_hash, window_started_at, request_count, updated_at)
  VALUES (p_shop_id, v_phone_hash, v_now, 1, v_now)
  ON CONFLICT (shop_id, subject_hash)
  DO UPDATE SET
    request_count = CASE
      WHEN private.digital_service_intake_rate_limits.window_started_at > v_now - interval '1 hour'
      THEN private.digital_service_intake_rate_limits.request_count + 1
      ELSE 1
    END,
    window_started_at = CASE
      WHEN private.digital_service_intake_rate_limits.window_started_at > v_now - interval '1 hour'
      THEN private.digital_service_intake_rate_limits.window_started_at
      ELSE v_now
    END,
    updated_at = v_now
  RETURNING request_count INTO v_count;

  IF v_count > 5 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE = 'Too many applications from this phone number. Please try again later.',
            DETAIL = 'Maximum 5 submissions per phone number per shop in a rolling 60-minute window.';
  END IF;

  INSERT INTO private.digital_service_intake_rate_limits
    (shop_id, subject_hash, window_started_at, request_count, updated_at)
  VALUES (p_shop_id, v_shop_hash, v_now, 1, v_now)
  ON CONFLICT (shop_id, subject_hash)
  DO UPDATE SET
    request_count = CASE
      WHEN private.digital_service_intake_rate_limits.window_started_at > v_now - interval '1 hour'
      THEN private.digital_service_intake_rate_limits.request_count + 1
      ELSE 1
    END,
    window_started_at = CASE
      WHEN private.digital_service_intake_rate_limits.window_started_at > v_now - interval '1 hour'
      THEN private.digital_service_intake_rate_limits.window_started_at
      ELSE v_now
    END,
    updated_at = v_now
  RETURNING request_count INTO v_count;

  IF v_count > 120 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE = 'This digital service centre is temporarily receiving too many requests. Please try again later.',
            DETAIL = 'Maximum 120 submissions per digital service centre in a rolling 60-minute window.';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION private.consume_digital_service_intake_limit(uuid, text)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.submit_digital_service_application(
  p_shop_id uuid,
  p_service_name text,
  p_applicant_name text,
  p_applicant_phone text,
  p_document_checklist text DEFAULT NULL::text,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_id uuid;
  v_number bigint;
BEGIN
  IF p_shop_id IS NULL OR NOT private.is_active_digital_service_shop(p_shop_id) THEN
    RAISE EXCEPTION 'This digital service centre is not currently accepting requests'
      USING ERRCODE = '55000';
  END IF;

  IF p_service_name IS NULL OR char_length(btrim(p_service_name)) NOT BETWEEN 1 AND 120
     OR p_applicant_name IS NULL OR char_length(btrim(p_applicant_name)) NOT BETWEEN 1 AND 120
     OR p_applicant_phone IS NULL OR p_applicant_phone !~ '^[0-9+() -]{7,20}$'
     OR char_length(regexp_replace(p_applicant_phone, '[^0-9]', '', 'g')) NOT BETWEEN 7 AND 15
     OR (p_document_checklist IS NOT NULL AND char_length(p_document_checklist) > 2000)
     OR (p_notes IS NOT NULL AND char_length(p_notes) > 500) THEN
    RAISE EXCEPTION 'Enter a valid service, applicant name, phone and short notes';
  END IF;

  PERFORM private.consume_digital_service_intake_limit(p_shop_id, p_applicant_phone);

  INSERT INTO public.digital_service_applications
    (shop_id, customer_id, service_name, applicant_name, applicant_phone, document_checklist, notes)
  VALUES
    (p_shop_id, auth.uid(), btrim(p_service_name), btrim(p_applicant_name),
     btrim(p_applicant_phone), nullif(btrim(p_document_checklist), ''),
     nullif(btrim(p_notes), ''))
  RETURNING id, application_number INTO v_id, v_number;

  RETURN pg_catalog.jsonb_build_object('id', v_id, 'application_number', v_number);
END;
$function$;
