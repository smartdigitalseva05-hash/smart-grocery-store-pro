-- The public registration page inserts a new shop application directly.
-- The existing INSERT RLS policy limits ownership and requires inactive,
-- unapproved, unsubscribed state; the activation trigger independently forces
-- all client-created shops to remain inactive until trusted approval/payment.
GRANT INSERT ON TABLE public.shops TO authenticated;
