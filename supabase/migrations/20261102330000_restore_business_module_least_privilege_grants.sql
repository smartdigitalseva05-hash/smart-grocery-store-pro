-- Restore only authenticated table operations actually used by shopkeeper.html.
-- Existing RLS policies remain the row-level authorization boundary.
GRANT SELECT, UPDATE ON TABLE public.electronics_service_jobs TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.hotel_booking_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.hotel_housekeeping_tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.office_leave_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.office_payroll_records TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.office_tasks TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.restaurant_reservations TO authenticated;
