-- This helper has no application or database callers. Do not expose
-- a SECURITY DEFINER shop-trial status oracle to authenticated clients.
REVOKE EXECUTE ON FUNCTION private.is_active_free_trial(uuid)
  FROM PUBLIC, anon, authenticated;
