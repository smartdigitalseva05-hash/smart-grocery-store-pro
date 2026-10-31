revoke insert,update on public.profiles from anon,authenticated;
grant select on public.profiles to authenticated;
grant update(full_name,phone) on public.profiles to authenticated;
revoke insert,update on public.shops from anon,authenticated;
grant select,delete on public.shops to authenticated;
grant insert(owner_id,name,slug,description,phone,email,address,city,business_type) on public.shops to authenticated;
