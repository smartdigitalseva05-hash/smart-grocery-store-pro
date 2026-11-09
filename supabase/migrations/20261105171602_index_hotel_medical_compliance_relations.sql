
create index if not exists hotel_payment_records_booking_request_idx on public.hotel_payment_records(booking_request_id) where booking_request_id is not null;
create index if not exists hotel_payment_records_reservation_idx on public.hotel_payment_records(reservation_id) where reservation_id is not null;
create index if not exists medical_compliance_batch_idx on public.medical_batch_compliance_checks(batch_id);
create index if not exists medical_compliance_checked_by_idx on public.medical_batch_compliance_checks(checked_by) where checked_by is not null;

