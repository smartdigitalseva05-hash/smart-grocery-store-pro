-- Give the private payment limiter event table a stable primary key.
ALTER TABLE private.payment_endpoint_rate_limit_events
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();

ALTER TABLE private.payment_endpoint_rate_limit_events
  ALTER COLUMN id SET NOT NULL;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'private.payment_endpoint_rate_limit_events'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE private.payment_endpoint_rate_limit_events
      ADD CONSTRAINT payment_endpoint_rate_limit_events_pkey PRIMARY KEY (id);
  END IF;
END
$migration$;

CREATE INDEX IF NOT EXISTS payment_endpoint_rate_limit_created_at_idx
  ON private.payment_endpoint_rate_limit_events (created_at);
