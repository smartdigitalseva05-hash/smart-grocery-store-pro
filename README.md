# Smart Grocery Store Pro

Grocery ordering platform with customer ordering, shopkeeper workspace, Owner controls, subscriptions and order tracking. First release is restricted to grocery stores.

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

## Free trial\n- One 7-day free trial per Shopkeeper account, enforced by a unique database claim.\n- Trial does not create a fake payment or paid subscription.\n- The trial uses the Basic plan limits (200 products, 500 orders/month).\n- Hourly Supabase Cron expires the trial, deactivates the shop and preserves its stored data.\n- Shopkeeper trial activation and product insert/update/delete passed authenticated database transaction tests; customer-facing product visibility and trial-expiry behavior also passed rollback tests.\n\n## Subscription payments
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
- Razorpay Edge Functions are ACTIVE; checkout, verification and webhook now use a separately created server-only Supabase secret-key client for privileged payment-row operations. Full Test Mode end-to-end payment verification is still pending.
- Current database has one active grocery shop on its one-time 7-day free trial (started 2026-10-31 03:53 UTC; expires 2026-11-07 03:53 UTC). The shop has no products or customer orders yet, so a live customer-order demo still needs a real product and a customer delivery address.
- Supabase Security Advisor reports leaked-password protection is disabled. Enable it in Auth settings before public launch if supported by the project plan.
- Performance Advisor reports unused-index notices; do not remove indexes without reviewing real query workload.

## Important
The existing `index.html` is intentionally preserved. Do not replace it without explicit approval.
