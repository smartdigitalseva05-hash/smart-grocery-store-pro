drop policy if exists digital_service_applications_public_insert on public.digital_service_applications;
revoke insert(id,shop_id,customer_id,service_name,applicant_name,applicant_phone,document_checklist,notes) on public.digital_service_applications from anon;
create or replace function private.submit_digital_service_application(p_shop_id uuid,p_service_name text,p_applicant_name text,p_applicant_phone text,p_document_checklist text default null,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_number bigint;
begin
 if p_shop_id is null or not private.is_active_digital_service_shop(p_shop_id) then raise exception 'This digital service centre is not currently accepting requests' using errcode='55000'; end if;
 if p_service_name is null or char_length(btrim(p_service_name)) not between 1 and 120 or p_applicant_name is null or char_length(btrim(p_applicant_name)) not between 1 and 120 or p_applicant_phone is null or p_applicant_phone !~ '^[0-9+() -]{7,20}$' or char_length(regexp_replace(p_applicant_phone,'[^0-9]','','g')) not between 7 and 15 or (p_document_checklist is not null and char_length(p_document_checklist)>2000) or (p_notes is not null and char_length(p_notes)>500) then raise exception 'Enter a valid service, applicant name, phone and short notes'; end if;
 insert into public.digital_service_applications(shop_id,customer_id,service_name,applicant_name,applicant_phone,document_checklist,notes)
 values(p_shop_id,auth.uid(),btrim(p_service_name),btrim(p_applicant_name),btrim(p_applicant_phone),nullif(btrim(p_document_checklist),''),nullif(btrim(p_notes),'')) returning id,application_number into v_id,v_number;
 return pg_catalog.jsonb_build_object('id',v_id,'application_number',v_number);
end;$$;
revoke all on function private.submit_digital_service_application(uuid,text,text,text,text,text) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.submit_digital_service_application(uuid,text,text,text,text,text) to anon,authenticated;
create or replace function public.submit_digital_service_application(p_shop_id uuid,p_service_name text,p_applicant_name text,p_applicant_phone text,p_document_checklist text default null,p_notes text default null)
returns jsonb language sql security invoker set search_path='' as $$ select private.submit_digital_service_application(p_shop_id,p_service_name,p_applicant_name,p_applicant_phone,p_document_checklist,p_notes); $$;
revoke all on function public.submit_digital_service_application(uuid,text,text,text,text,text) from public;
grant execute on function public.submit_digital_service_application(uuid,text,text,text,text,text) to anon,authenticated;
