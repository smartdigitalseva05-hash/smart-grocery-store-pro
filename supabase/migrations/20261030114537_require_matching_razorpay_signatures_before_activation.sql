
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('private.verify_payment_and_activate(uuid)'::regprocedure);
  v_def := replace(
    v_def,
    'or coalesce(v_pay.gateway_payload ->> ''captured'', ''false'') <> ''true''',
    'or coalesce(v_pay.gateway_payload ->> ''captured'', ''false'') <> ''true''
     or v_pay.gateway_payload ->> ''razorpay_order_id'' is distinct from v_pay.gateway_order_id
     or v_pay.gateway_payload ->> ''razorpay_payment_id'' is distinct from v_pay.gateway_transaction_id
     or not (
       coalesce(v_pay.gateway_payload ->> ''signature_verified'', ''false'') = ''true''
       or coalesce(v_pay.gateway_payload ->> ''webhook_signature_verified'', ''false'') = ''true''
     )'
  );
  if v_def = pg_get_functiondef('private.verify_payment_and_activate(uuid)'::regprocedure) then
    raise exception 'Expected payment verification condition was not found';
  end if;
  execute v_def;
end;
$$;
