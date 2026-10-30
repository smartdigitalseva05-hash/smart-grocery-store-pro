# Smart Grocery Store Pro

Multi-vendor grocery ordering platform with customer ordering, shopkeeper workspaces, Owner controls, subscriptions and order tracking.

## Workspaces
- `portal.html` — platform portal and live subscription pricing.
- `apply-shop.html` — customer signup/login and shop application submission.
- `index.html` — customer grocery storefront.
- `my-orders.html` — customer order history and pending unpaid-order cancellation.
- `shopkeeper.html` — shopkeeper products, stock, subscriptions and incoming orders.
- `owner.html` — Owner dashboard, shop approvals, catalog controls, payment review and audit log.

## Subscription pricing
| Plan | Monthly | Annual |
|---|---:|---:|
| Basic | ₹99 | ₹990 |
| Pro | ₹199 | ₹1,990 |
| Enterprise | ₹299 | ₹2,990 |

Annual prices are 10 months of the monthly price. Pricing is read from the Supabase `subscription_plans` table.

## Orders
Customer checkout currently supports cash on delivery (COD). Shopkeepers can accept pending COD orders, move them through delivery, and mark COD as collected only when delivery is confirmed. Customer online grocery payments are not implemented.

## Subscription payments
The three Razorpay Edge Functions are deployed:
- `razorpay-subscription-checkout`
- `razorpay-verify-subscription-payment`
- `razorpay-payment-webhook`

Subscription payments are **not ready for live use** until the merchant adds the three Razorpay secrets in Supabase Edge Function Secrets, registers the webhook, and completes Test Mode end-to-end checks. Follow [PAYMENT_SETUP.md](./PAYMENT_SETUP.md). Never put gateway secrets in frontend code, GitHub, or chat.

## Database security and automation
- Row Level Security is enabled on all 14 public application tables.
- Sensitive authorization and tenant isolation are enforced by database policies and validated RPCs.
- Supabase Cron runs subscription expiry checks hourly.
- The frontend uses a Supabase publishable key only; never expose a service-role/secret key in browser code.

## Deployment and verification status
- GitHub Pages deployment workflow is configured; the latest recorded deployment run succeeded.
- Inline JavaScript syntax and page element-ID reference checks passed for the six HTML pages.
- Razorpay Edge Function deployment status is ACTIVE for all three functions.
- Full real-world end-to-end testing is still pending because there are currently no registered shops, products, orders or payment records in the database.
- Supabase Security Advisor currently reports leaked-password protection as disabled. Enable it in Auth settings if the project plan supports it.
- Performance Advisor reports unused-index notices; do not remove indexes without reviewing real query workload.

## Important
The existing `index.html` is intentionally preserved. Do not replace it without explicit approval.
