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

## Specialized business workspaces

The shopkeeper dashboard now includes these vertical-specific tools:
- **Garments:** SKU, size and colour variants with per-variant price, stock, availability, edit and delete controls.
- **Jewellery:** item code, metal type, purity, gross/net weight, stone weight, metal rate, making-charge method, hallmark and certificate details. The displayed metal-plus-making estimate is indicative only and excludes stones, taxes and other charges.
- **Restaurant:** table register with seating capacity and live table status; menu catalogue with price, category and preparation time; multi-item kitchen tickets for table/takeaway orders with per-item quantity and notes, guest count and ticket status (new, preparing, ready, served, cancelled).
- **Hotel:** room register with room type, floor, guest capacity, nightly rate and room status; guest reservations with dates, phone, guest count, booking status and check-in/check-out; database trigger prevents overlapping active reservations for the same room.
- **Office / Company:** employee register with code, contact, designation and employment type; date-wise attendance with present, absent, half-day and leave status plus check-in/check-out times.
- **Electronics:** device register with IMEI 1/2, serial number, brand/model, supplier, purchase/sale price, warranty dates and device lifecycle status; duplicate IMEI/serial values are blocked within each shop.
- **Medical:** batch-wise medicine inventory with manufacturing/expiry dates, quantity, MRP, supplier, prescription-required flag and expiry alerts. This is inventory support, not a complete compliant pharmacy workflow.
- **Digital Seva:** application register with service/applicant details, phone, reference number, applied/expected dates, document checklist, status progression and fee/payment balance tracking.

Other planned modules (restaurant kitchen tickets/POS, hotel rooms and bookings, employee attendance, electronics IMEI/warranty, medical batch/expiry and Digital Seva application tracking) are not yet complete. The shared product/order framework is not a substitute for those specialist workflows.

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
