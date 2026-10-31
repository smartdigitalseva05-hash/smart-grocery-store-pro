# Razorpay setup — Smart Grocery Store Pro

The server-side Razorpay Edge Functions are deployed. Payments are **not live** until the merchant creates a Razorpay account, adds API credentials to Supabase Edge Function Secrets, and registers the webhook.

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

The webhook verifies the HMAC-SHA256 signature against the original raw request body. It ignores non-captured payment events and checks the order reference, INR currency and expected amount before applying a subscription.

If Razorpay reports a captured payment but subscription activation temporarily fails, retry verification with the **same payment ID and transaction**. The verification endpoint now safely retries the same captured transaction; do not start a second payment for that reference.

## 3. Deployed Edge Functions

- razorpay-subscription-checkout — requires a signed-in user JWT; creates/reuses a server-side Razorpay order.
- razorpay-verify-subscription-payment — requires a signed-in user JWT; validates the checkout signature and confirms the captured payment with Razorpay.
- razorpay-payment-webhook — public webhook endpoint; verifies Razorpay's webhook signature before processing.

## 4. Test before going live

1. Add Test Mode API keys and webhook secret.
2. Apply for a shop and have the Owner approve the shopkeeper account.
3. Sign in to the Shopkeeper Workspace.
4. Select Basic ₹99, Pro ₹199 or Enterprise ₹299 (monthly), or the corresponding annual plan.
5. Complete a test payment and verify that the subscription becomes active.
6. Confirm the shop is active and product management is unlocked.
7. Test failed, dismissed, duplicate and delayed webhook deliveries.
8. Only after successful testing, replace Test Mode credentials with Live Mode credentials and verify the webhook configuration again.

Do not accept real customer payments until the complete test flow and refund/support process have been reviewed.
