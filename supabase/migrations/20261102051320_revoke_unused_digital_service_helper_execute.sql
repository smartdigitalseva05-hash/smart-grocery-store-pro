-- This helper is called only inside the SECURITY DEFINER public-intake
-- implementation. It is not used by RLS policies or browser clients, so
-- clients must not be able to invoke it directly through an exposed schema.
REVOKE EXECUTE ON FUNCTION private.is_active_digital_service_shop(uuid)
  FROM PUBLIC, anon, authenticated;
