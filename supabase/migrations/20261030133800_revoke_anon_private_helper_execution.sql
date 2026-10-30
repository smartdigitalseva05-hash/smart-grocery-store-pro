-- Private authorization helpers are used by authenticated RLS policies only.
-- Anonymous callers must not be able to probe role/shop ownership predicates.
revoke all privileges on function private.is_shop_owner(uuid) from public, anon;
revoke all privileges on function private.is_super_admin() from public, anon;
grant execute on function private.is_shop_owner(uuid) to authenticated;
grant execute on function private.is_super_admin() to authenticated;
