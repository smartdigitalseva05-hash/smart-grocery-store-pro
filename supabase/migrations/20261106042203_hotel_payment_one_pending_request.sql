create unique index if not exists hotel_payment_records_one_pending_per_request
on public.hotel_payment_records (booking_request_id)
where booking_request_id is not null and payment_status = 'pending';
