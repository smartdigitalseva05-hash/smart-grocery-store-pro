alter table public.digital_service_applications add column if not exists customer_id uuid references auth.users(id) on delete set null;
create index if not exists digital_service_applications_customer_id_idx on public.digital_service_applications(customer_id);
create index if not exists digital_service_applications_shop_created_idx on public.digital_service_applications(shop_id,created_at desc);
create or replace function private.is_active_digital_service_shop(p_shop_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.shops s join public.profiles p on p.id=s.owner_id where s.id=p_shop_id and s.business_type='digital_services' and s.is_active=true and s.status='active'::public.shop_status and s.subscription_expires_at>pg_catalog.now() and p.role='shopkeeper'::public.user_role and p.is_active=true);
$$;
revoke all on function private.is_active_digital_service_shop(uuid) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.is_active_digital_service_shop(uuid) to anon,authenticated;
grant insert(id,shop_id,customer_id,service_name,applicant_name,applicant_phone,document_checklist,notes) on public.digital_service_applications to anon,authenticated;
drop policy if exists digital_service_applications_public_insert on public.digital_service_applications;
create policy digital_service_applications_public_insert on public.digital_service_applications for insert to anon,authenticated with check(application_status='submitted' and service_fee=0 and amount_paid=0 and reference_number is null and receipt_number is null and expected_date is null and customer_id is not distinct from (select auth.uid()) and private.is_active_digital_service_shop(shop_id));
create or replace function private.guard_digital_service_application_update() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.shop_id is distinct from old.shop_id or new.application_number is distinct from old.application_number or new.customer_id is distinct from old.customer_id or new.service_name is distinct from old.service_name or new.applicant_name is distinct from old.applicant_name or new.applicant_phone is distinct from old.applicant_phone or new.applied_on is distinct from old.applied_on then raise exception 'Customer application details cannot be changed after submission'; end if;
 if old.application_status='submitted' and new.application_status not in('submitted','under_review','rejected','cancelled') then raise exception 'A submitted application must be reviewed before approval or completion'; elsif old.application_status='under_review' and new.application_status not in('under_review','approved','rejected','completed','cancelled') then raise exception 'Invalid application status transition'; elsif old.application_status='approved' and new.application_status not in('approved','completed','cancelled') then raise exception 'An approved application can only be completed or cancelled'; elsif old.application_status in('completed','rejected','cancelled') and new.application_status is distinct from old.application_status then raise exception 'A closed application cannot be reopened'; end if;
 if new.amount_paid>new.service_fee then raise exception 'Amount paid cannot exceed the service fee'; end if;
 new.updated_at:=pg_catalog.now();return new;
end;$$;
revoke all on function private.guard_digital_service_application_update() from public,anon,authenticated;
drop trigger if exists digital_service_applications_guard_update on public.digital_service_applications;
create trigger digital_service_applications_guard_update before update on public.digital_service_applications for each row execute function private.guard_digital_service_application_update();
