
-- Keep the public owner-profile verification endpoints as SECURITY INVOKER wrappers.
-- All privileged table access stays in the private schema and the issue path requires
-- an active Super Admin with AAL2 and a verified TOTP factor.

create or replace function private.issue_owner_profile_verification_impl()
returns table(verify_url text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_expires timestamptz;
begin
  if v_uid is null or not private.is_super_admin() then
    raise exception using errcode='42501',
      message='An active Super Admin with verified authenticator MFA is required.';
  end if;

  if exists (
    select 1
    from public.owner_profile_verification_tokens t
    where t.owner_user_id=v_uid
      and t.created_at > now() - interval '30 seconds'
  ) then
    raise exception using errcode='P0001',
      message='Please wait 30 seconds before creating another QR.';
  end if;

  update public.owner_profile_verification_tokens
  set status='revoked', revoked_at=now()
  where owner_user_id=v_uid and status='active';

  v_code := encode(extensions.gen_random_bytes(32), 'hex');
  v_expires := now() + interval '365 days';

  insert into public.owner_profile_verification_tokens
    (owner_user_id, token_hash, display_name, designation, organization, status, expires_at)
  values
    (v_uid,
     encode(extensions.digest(convert_to(v_code,'UTF8'),'sha256'),'hex'),
     'Hemanta Sahu',
     'Founder & Platform Owner',
     'Smart Business Pro',
     'active',
     v_expires);

  return query
    select 'https://smartdigitalseva05-hash.github.io/smart-grocery-store-pro/verify-owner.html?code=' || v_code,
           v_expires;
end;
$function$;

create or replace function private.verify_owner_profile_token_impl(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_record public.owner_profile_verification_tokens%rowtype;
begin
  if p_code is null or p_code !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('verified',false,'error','Invalid or missing verification code.');
  end if;

  select *
  into v_record
  from public.owner_profile_verification_tokens t
  where t.token_hash=encode(extensions.digest(convert_to(p_code,'UTF8'),'sha256'),'hex')
    and t.status='active'
    and t.expires_at > now()
  limit 1;

  if not found then
    return jsonb_build_object('verified',false,'error','This QR is invalid, expired, or has been revoked.');
  end if;

  update public.owner_profile_verification_tokens
  set last_verified_at=now()
  where id=v_record.id;

  return jsonb_build_object(
    'verified',true,
    'status','ACTIVE',
    'profile',jsonb_build_object(
      'name',v_record.display_name,
      'designation',v_record.designation,
      'organization',v_record.organization
    ),
    'issued_at',v_record.created_at,
    'expires_at',v_record.expires_at,
    'notice','This confirms an active Smart Business Pro owner profile record. It is not a government identity document.'
  );
end;
$function$;

create or replace function public.issue_owner_profile_verification()
returns table(verify_url text, expires_at timestamptz)
language sql
security invoker
set search_path = ''
as $function$
  select * from private.issue_owner_profile_verification_impl();
$function$;

create or replace function public.verify_owner_profile_token(p_code text)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.verify_owner_profile_token_impl(p_code);
$function$;

revoke all on function private.issue_owner_profile_verification_impl() from public, anon, authenticated;
revoke all on function private.verify_owner_profile_token_impl(text) from public, anon, authenticated;
grant usage on schema private to anon, authenticated;
grant execute on function private.issue_owner_profile_verification_impl() to authenticated;
grant execute on function private.verify_owner_profile_token_impl(text) to anon, authenticated;

revoke all on function public.issue_owner_profile_verification() from public, anon;
grant execute on function public.issue_owner_profile_verification() to authenticated;
revoke all on function public.verify_owner_profile_token(text) from public;
grant execute on function public.verify_owner_profile_token(text) to anon, authenticated;

revoke all on table public.owner_profile_verification_tokens from public, anon, authenticated;
drop policy if exists owner_profile_verification_tokens_deny_browser on public.owner_profile_verification_tokens;
create policy owner_profile_verification_tokens_deny_browser
on public.owner_profile_verification_tokens
for all
to anon, authenticated
using (false)
with check (false);
