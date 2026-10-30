
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create or replace function private.is_super_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'super_admin'::public.user_role
      and is_active = true
  );
$$;

create or replace function private.is_shop_owner(p_shop_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.shops
    where id = p_shop_id and owner_id = auth.uid()
  );
$$;

revoke all on function private.is_super_admin() from public;
revoke all on function private.is_shop_owner(uuid) from public;
grant execute on function private.is_super_admin() to anon, authenticated;
grant execute on function private.is_shop_owner(uuid) to anon, authenticated;

do $$
declare
  pol record;
  func_row record;
  v_using text;
  v_check text;
  v_sql text;
  v_def text;
begin
  for pol in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        coalesce(qual, '') ilike '%is_super_admin()%'
        or coalesce(qual, '') ilike '%is_shop_owner(%'
        or coalesce(with_check, '') ilike '%is_super_admin()%'
        or coalesce(with_check, '') ilike '%is_shop_owner(%'
      )
  loop
    v_using := pol.qual;
    v_check := pol.with_check;
    if v_using is not null then
      v_using := replace(v_using, 'public.is_super_admin()', 'private.is_super_admin()');
      v_using := replace(v_using, 'is_super_admin()', 'private.is_super_admin()');
      v_using := replace(v_using, 'public.is_shop_owner(', 'private.is_shop_owner(');
      v_using := replace(v_using, 'is_shop_owner(', 'private.is_shop_owner(');
    end if;
    if v_check is not null then
      v_check := replace(v_check, 'public.is_super_admin()', 'private.is_super_admin()');
      v_check := replace(v_check, 'is_super_admin()', 'private.is_super_admin()');
      v_check := replace(v_check, 'public.is_shop_owner(', 'private.is_shop_owner(');
      v_check := replace(v_check, 'is_shop_owner(', 'private.is_shop_owner(');
    end if;
    v_sql := format('alter policy %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    if v_using is not null then v_sql := v_sql || format(' using (%s)', v_using); end if;
    if v_check is not null then v_sql := v_sql || format(' with check (%s)', v_check); end if;
    execute v_sql;
  end loop;

  for func_row in
    select pp.oid
    from pg_proc pp
    join pg_namespace ns on ns.oid = pp.pronamespace
    where ns.nspname = 'public'
      and pp.proname not in ('is_super_admin', 'is_shop_owner')
      and (
        pp.prosrc ilike '%is_super_admin()%'
        or pp.prosrc ilike '%is_shop_owner(%'
      )
  loop
    v_def := pg_get_functiondef(func_row.oid);
    v_def := replace(v_def, 'public.is_super_admin()', 'private.is_super_admin()');
    v_def := replace(v_def, 'is_super_admin()', 'private.is_super_admin()');
    v_def := replace(v_def, 'public.is_shop_owner(', 'private.is_shop_owner(');
    v_def := replace(v_def, 'is_shop_owner(', 'private.is_shop_owner(');
    execute v_def;
  end loop;
end;
$$;

revoke all on function public.is_super_admin() from public, anon, authenticated;
revoke all on function public.is_shop_owner(uuid) from public, anon, authenticated;
