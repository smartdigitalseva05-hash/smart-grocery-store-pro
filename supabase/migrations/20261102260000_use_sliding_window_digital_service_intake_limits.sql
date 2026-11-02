-- Replace the fixed-window counter with true sliding 60-minute event windows.
-- Each accepted intake writes a phone-scoped and shop-scoped HMAC event.
-- Transaction-scoped advisory locks serialize same-phone and shop-wide checks.
CREATE TABLE IF NOT EXISTS private.digital_service_intake_rate_limit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  scope text NOT NULL CHECK (scope IN ('phone', 'shop')),
  subject_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS digital_service_intake_rate_limit_events_lookup_idx
  ON private.digital_service_intake_rate_limit_events
    (shop_id, scope, subject_hash, created_at DESC);
CREATE INDEX IF NOT EXISTS digital_service_intake_rate_limit_events_created_idx
  ON private.digital_service_intake_rate_limit_events (created_at);

ALTER TABLE private.digital_service_intake_rate_limit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.digital_service_intake_rate_limit_events
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON SEQUENCE private.digital_service_intake_rate_limit_events_id_seq
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

  -- Always acquire locks in the same order to avoid deadlocks.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'digital-intake-phone:' || p_shop_id::text || ':' || pg_catalog.encode(v_phone_hash, 'hex'),
      0
    )
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('digital-intake-shop:' || p_shop_id::text, 0)
  );

  DELETE FROM private.digital_service_intake_rate_limit_events
  WHERE created_at < v_now - interval '7 days';

  SELECT count(*)::integer INTO v_count
  FROM private.digital_service_intake_rate_limit_events
  WHERE shop_id = p_shop_id
    AND scope = 'phone'
    AND subject_hash = v_phone_hash
    AND created_at > v_now - interval '1 hour';

  IF v_count >= 5 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE = 'Too many applications from this phone number. Please try again later.',
            DETAIL = 'Maximum 5 submissions per phone number per shop in any rolling 60-minute window.';
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM private.digital_service_intake_rate_limit_events
  WHERE shop_id = p_shop_id
    AND scope = 'shop'
    AND subject_hash = v_shop_hash
    AND created_at > v_now - interval '1 hour';

  IF v_count >= 120 THEN
    RAISE SQLSTATE 'PT429'
      USING MESSAGE = 'This digital service centre is temporarily receiving too many requests. Please try again later.',
            DETAIL = 'Maximum 120 submissions per digital service centre in any rolling 60-minute window.';
  END IF;

  INSERT INTO private.digital_service_intake_rate_limit_events
    (shop_id, scope, subject_hash, created_at)
  VALUES
    (p_shop_id, 'phone', v_phone_hash, v_now),
    (p_shop_id, 'shop', v_shop_hash, v_now);
END;
$function$;

REVOKE ALL ON FUNCTION private.consume_digital_service_intake_limit(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.consume_digital_service_intake_limit(uuid, text)
  TO postgres;
