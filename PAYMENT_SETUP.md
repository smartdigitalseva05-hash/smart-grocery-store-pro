# Razorpay setup — Smart Business Pro

The subscription and hotel-booking Razorpay Edge Functions are deployed. Payments are **not ready for public/live use** until the merchant adds API credentials to Supabase Edge Function Secrets, registers the webhook, and completes the Test Mode acceptance checks below.

## 1. Add secrets in Supabase

Open Supabase Dashboard → Project → Edge Functions → Secrets. Add these three values:

- RAZORPAY_KEY_ID — Razorpay API Key ID.
- RAZORPAY_KEY_SECRET — matching Razorpay API Key Secret.
- RAZORPAY_WEBHOOK_SECRET — a separate webhook signing secret chosen when registering the webhook.

Use Razorpay **Test Mode** credentials first. Do not paste any secret into GitHub, website code, or ChatGPT.

Supabase already provides its own URL and API keys to Edge Functions. Do not create a browser-side service-role key.

## 2. Register the Razorpay webhook

Webhook URL:

https://wqlopfftzvsjsxmrmxeq.supabase.co/functions/v1/razorpay-payment-webhook

Subscribe to:
- payment.captured
- order.paid

Set the webhook secret to the exact same value stored as RAZORPAY_WEBHOOK_SECRET.

The webhook verifies the HMAC-SHA256 signature against the original raw request body. It processes captured subscription and hotel-booking payments, checking the matching order reference, INR currency and exact expected amount before recording a payment or activating a subscription.

If Razorpay reports a captured payment but subscription activation temporarily fails, retry verification with the **same payment ID and transaction**. The verification endpoint now safely retries the same captured transaction; do not start a second payment for that reference.

## 3. Deployed Edge Functions

- razorpay-subscription-checkout — requires a signed-in user JWT; creates/reuses a server-side Razorpay order.
- razorpay-verify-subscription-payment — requires a signed-in user JWT; validates the checkout signature and confirms the captured payment with Razorpay.
- razorpay-payment-webhook — public webhook endpoint; verifies Razorpay's webhook signature before processing captured subscription and hotel payments.
- hotel-payment-checkout — guest booking endpoint; accepts only a hotel-approved booking with an assigned reservation and calculates the payable amount from the saved room rate and stay dates on the server.
- hotel-payment-verify — guest verification endpoint; validates the Razorpay callback signature and independently confirms the captured payment, order, INR currency and exact amount with Razorpay.

**Hotel payment hardening gate:** The current deployed hotel endpoints support the payment flow, but the newer per-booking rate-limit implementation (5 checkout attempts and 10 verification attempts per rolling 15 minutes, fail-closed) is only in GitHub source and CI; it has not yet been deployed to production. Add IP/device abuse controls before opening this guest-facing flow publicly.

## 4. Test before going live

1. Add Test Mode API keys and webhook secret.
2. Register the webhook for `payment.captured` and `order.paid`.
3. Apply for a shop, have the Owner approve it, and sign in to the Shopkeeper Workspace.
4. Complete a subscription Test Mode payment; verify the subscription activates only after server-side gateway confirmation.
5. Test failed, dismissed, duplicate and delayed subscription webhook deliveries; retry only with the same payment reference.
6. Create a hotel booking request as a guest; confirm it cannot be paid before hotel approval and room assignment.
7. Approve the hotel booking, assign a matching room, then pay the server-calculated amount through Razorpay.
8. Verify the hotel payment is recorded only after exact captured-payment confirmation; test dismissed, failed, duplicate and delayed callbacks/webhooks.
9. Deploy and verify the hotel endpoint rate-limit hardening and add IP/device abuse controls before public hotel payment use.
10. Only after all checks pass, replace Test Mode credentials with Live Mode credentials and verify the webhook configuration again.

Do not accept real customer payments until the complete test flow and refund/support process have been reviewed.
