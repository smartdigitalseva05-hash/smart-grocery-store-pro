# Smart Grocery Store Pro

Multi-business commerce and operations platform with a grocery customer storefront, shopkeeper workspaces, Owner controls, subscriptions, order tracking and specialist modules for garments, jewellery, restaurants, hotels, offices, electronics, medical inventory and Digital Seva.

## Workspaces
- `portal.html` — platform portal and live subscription pricing.
- `shopkeeper-benefits.html` — shopkeeper problem/solution landing page with a clear distinction between available tools and planned features.
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

## Shopkeeper growth roadmap

The shopkeeper benefits page explains common local-store problems and maps them to platform workflows. Current workspace capabilities include product/price/stock management, incoming order management, order status updates and the COD workflow. The following customer-growth tools are roadmap items and must not be marketed as live until implemented and acceptance-tested:
- Shopkeeper QR code generator
- WhatsApp product and offer sharing tools
- Customer repeat-order flow
- Sales analytics and best-seller reporting
- Configurable low-stock notifications
- Shopkeeper Growth Score with transparent, explainable metrics

## Specialized business workspaces

The shopkeeper dashboard now includes these vertical-specific tools:
- **Garments:** SKU, size and colour variants with per-variant price, stock, availability, edit and delete controls.
- **Jewellery:** item code, metal type, purity, gross/net weight, stone weight, metal rate, making-charge method, hallmark and certificate details. The displayed metal-plus-making estimate is indicative only and excludes stones, taxes and other charges.
- **Restaurant:** table register with seating capacity and live table status; menu catalogue; multi-item kitchen tickets for table/takeaway orders; online customer order items automatically create kitchen tickets, and order progress synchronizes kitchen status (preparing, ready, served, cancelled).
- **Hotel:** room register with room type, floor, guest capacity, nightly rate and room status; guest reservations with dates, phone, guest count, booking status and check-in/check-out; database trigger prevents overlapping active reservations for the same room.
- **Office / Company:** employee register with code, contact, designation and employment type; date-wise attendance with present, absent, half-day and leave status plus check-in/check-out times.
- **Electronics:** device register with IMEI 1/2, serial number, brand/model, supplier, purchase/sale price, warranty dates and device lifecycle status; duplicate IMEI/serial values are blocked within each shop.
- **Medical:** batch-wise medicine inventory with manufacturing/expiry dates, quantity, MRP, supplier, prescription-required flag and expiry alerts. This is inventory support, not a complete compliant pharmacy workflow.
- **Digital Seva:** application register with service/applicant details, phone, reference number, applied/expected dates, document checklist, status progression and fee/payment balance tracking.

Remaining specialist work includes restaurant POS and customer table reservations; hotel online guest booking, payment and housekeeping; office payroll, leave and task workflows; electronics repair jobs and warranty claims; medical prescription/dispensing and regulatory workflows; and Digital Seva document uploads plus official portal integrations. The implemented modules provide operational foundations; full end-to-end acceptance testing for every business type is still pending.

## Orders
Customer checkout currently supports cash on delivery (COD). Shopkeepers can accept pending COD orders, move them through delivery, and mark COD as collected only when delivery is confirmed. Customer online grocery payments are not implemented.

## Free trial
- One 7-day free trial per Shopkeeper account, enforced by a unique database claim.
- Trial does not create a fake payment or paid subscription.
- The trial uses the Basic plan limits (200 products, 500 orders/month).
- Hourly Supabase Cron expires the trial, deactivates the shop and preserves its stored data.
- Shopkeeper trial activation and product insert/update/delete passed authenticated database transaction tests; customer-facing product visibility and trial-expiry behavior also passed rollback tests.

## Subscription payments
The three Razorpay Edge Functions are deployed:
- `razorpay-subscription-checkout`
- `razorpay-verify-subscription-payment`
- `razorpay-payment-webhook`

Subscription payments are **not ready for live use** until the merchant adds the three Razorpay secrets in Supabase Edge Function Secrets, registers the webhook, and completes Test Mode end-to-end checks. Follow [PAYMENT_SETUP.md](./PAYMENT_SETUP.md). Never put gateway secrets in frontend code, GitHub, or chat.

## Database security and automation
- Row Level Security is enabled on all 28 public application tables (verified from PostgreSQL catalog).
- Sensitive authorization and tenant isolation are enforced by database policies and validated RPCs.
- Supabase Cron runs subscription expiry checks hourly.
- The frontend uses a Supabase publishable key only; never expose a service-role/secret key in browser code.

## Deployment and verification status
- GitHub Pages deployment workflow is configured; the latest recorded deployment run succeeded.
- Inline JavaScript syntax and page element-ID reference checks passed for the six HTML pages.
- Razorpay Edge Functions are ACTIVE; checkout, verification and webhook now use a separately created server-only Supabase secret-key client for privileged payment-row operations. Full Test Mode end-to-end payment verification is still pending.
- Current database has one active grocery shop on its one-time 7-day free trial (started 2026-10-31 03:53 UTC; expires 2026-11-07 03:53 UTC), one product and zero customer orders. A live checkout acceptance test still needs a customer account and delivery address.
- All 11 business types now have active catalogue categories: 4 Grocery, 8 Daily Needs, and 4 each for the other nine types (48 total). Category names are starter defaults and can be refined by the platform Owner.
- Supabase Security Advisor reports leaked-password protection is disabled. Enable it in Auth settings before public launch if supported by the project plan.
- Performance Advisor reports unused-index notices; do not remove indexes without reviewing real query workload.

## Important
The existing `index.html` is intentionally preserved. Do not replace it without explicit approval.
