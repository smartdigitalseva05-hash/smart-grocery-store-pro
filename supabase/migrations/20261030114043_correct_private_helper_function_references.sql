
do $$
declare f record; v_def text;
begin
  for f in
    select p.oid
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and (
      p.prosrc ilike '%private.private.is_super_admin()%'
      or p.prosrc ilike '%private.private.is_shop_owner(%'
    )
  loop
    v_def := pg_get_functiondef(f.oid);
    v_def := replace(v_def, 'private.private.is_super_admin()', 'private.is_super_admin()');
    v_def := replace(v_def, 'private.private.is_shop_owner(', 'private.is_shop_owner(');
    execute v_def;
  end loop;
end;
$$;
