-- Trigger functions are invoked by PostgreSQL triggers, not as client RPCs.
-- Revoke direct EXECUTE from API roles while preserving trigger definitions and owners.
-- PostgreSQL checks trigger-function EXECUTE when CREATE TRIGGER is issued,
-- not for each row-level trigger invocation.
do $$
declare
  item record;
  trigger_function_count integer := 0;
begin
  for item in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.prorettype = 'trigger'::regtype
      and exists (
        select 1 from pg_trigger t
        where t.tgfoid = p.oid and not t.tgisinternal
      )
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', item.signature);
    trigger_function_count := trigger_function_count + 1;
  end loop;

  if trigger_function_count = 0 then
    raise exception 'Expected private trigger functions were not found; refusing to apply an empty hardening migration';
  end if;
end;
$$;

-- Post-migration invariant: every attached private trigger function is unavailable
-- for direct execution by anon/authenticated API roles.
do $$
declare
  exposed_count integer;
begin
  select count(*) into exposed_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.prorettype = 'trigger'::regtype
    and exists (select 1 from pg_trigger t where t.tgfoid = p.oid and not t.tgisinternal)
    and (has_function_privilege('anon', p.oid, 'EXECUTE')
      or has_function_privilege('authenticated', p.oid, 'EXECUTE'));

  if exposed_count <> 0 then
    raise exception 'Private trigger function direct-execution grants remain for % functions', exposed_count;
  end if;
end;
$$;
