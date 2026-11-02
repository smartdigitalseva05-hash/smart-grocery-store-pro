-- Explicit deny-all RLS policy for browser roles on the private limiter store.
CREATE POLICY payment_endpoint_rate_limit_deny_all
ON private.payment_endpoint_rate_limit_events
FOR ALL
TO anon, authenticated
USING (false)
WITH CHECK (false);
