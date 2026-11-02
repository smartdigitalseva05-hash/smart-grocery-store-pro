-- Private limiter tables are only accessed by narrowly scoped SECURITY DEFINER
-- functions. Make the default-deny RLS posture explicit as a second barrier.
DO $migration$
DECLARE v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'digital_service_intake_rate_limit_events',
    'digital_service_intake_rate_limit_key',
    'digital_service_intake_rate_limits',
    'public_intake_rate_limit_events',
    'public_intake_rate_limit_key'
  ] LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS deny_direct_access ON private.%I',
      v_table
    );
    EXECUTE format(
      'CREATE POLICY deny_direct_access ON private.%I FOR ALL TO PUBLIC USING (false) WITH CHECK (false)',
      v_table
    );
  END LOOP;
END;
$migration$;
