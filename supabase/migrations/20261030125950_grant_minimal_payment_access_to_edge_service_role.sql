GRANT SELECT (
  id,
  user_id,
  amount,
  currency,
  status,
  verified,
  gateway,
  gateway_order_id,
  shop_subscription_id,
  gateway_payload
) ON TABLE public.payments TO service_role;

GRANT UPDATE (
  gateway_order_id,
  gateway_payload,
  status,
  gateway_transaction_id
) ON TABLE public.payments TO service_role;