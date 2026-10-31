alter table public.digital_service_applications
  add constraint digital_service_apps_paid_not_over_fee
  check (amount_paid <= service_fee);

alter table public.digital_service_applications
  add constraint digital_service_apps_expected_date_valid
  check (expected_date is null or expected_date >= applied_on);
