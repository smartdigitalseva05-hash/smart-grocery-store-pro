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

## Shopkeeper growth tools — implementation status

Added to the shopkeeper workspace and customer storefront:
- Shop-specific QR link and QR image download (QR rendering uses a CDN library).
- WhatsApp share composer that opens WhatsApp with a prefilled message; the shopkeeper manually reviews and sends it.
- Recent order analytics (latest 100 accessible orders), paid/collected revenue, delivered count and product count.
- Configurable low-stock threshold alerts based on current product stock.
- Transparent operational-readiness score with a four-part breakdown.
- Customer repeat-order shortcut from My Orders; it restores only currently available items, caps quantities to stock, and requires the customer to review the cart.
- Shop-specific public catalogue URL via `index.html?shop_id=...`.

These code paths are committed but still require browser/device end-to-end testing with a real shopkeeper account and a customer account. QR generation requires internet access to load its QR library. WhatsApp is a share handoff, not automated bulk messaging. Analytics are limited to the latest 100 accessible orders and do not represent audited accounts or guaranteed profit.

## Shopkeeper growth roadmap

The shopkeeper benefits page explains common local-store problems and maps them to platform workflows. Current workspace capabilities include product/price/stock management, incoming order management, order status updates and the COD workflow. The following customer-growth tools are now present in the shopkeeper/customer code paths and must remain labelled as built but testing-pending until real-account browser/device acceptance testing is complete:
- Shop-specific QR catalogue and downloadable QR image (QR library requires internet access).
- WhatsApp message composer and share handoff (the shopkeeper manually reviews and sends; no bulk automation).
- Customer repeat-order flow that restores only currently available items and caps quantities to current stock.
- Sales analytics for the latest 100 accessible orders, including a best-selling-products ranking; these are operational summaries, not audited accounts or profit calculations.
- Configurable low-stock threshold alerts shown in the shopkeeper dashboard.
- Transparent four-part Shopkeeper Growth Score; it measures operational readiness, not business profitability.
- Grocery-only supplier register, purchase invoice details, atomic purchase recording that increments product stock, and an append-only stock movement record. Purchase and movement writes occur through a validated database function; supplier and history access are shop-scoped with row-level security.
- Grocery customer orders now add a `sale` stock-movement record alongside the atomic stock deduction; cancellation of eligible unpaid COD orders restores stock and records an `order_cancelled` movement. Both records reference the originating order for traceability.
- Grocery daily expense register with validated categories, date and amount, shop-scoped row-level security, and a current-month recorded-expense summary. It is intentionally not labelled as profit because complete cost-of-goods and payment reconciliation are not yet implemented.
- Grocery supplier payment ledger with cash/UPI/bank/cheque/other methods, payment references and notes; immutable payment entries are shop-scoped under RLS, linked to the supplier in the same shop by a composite foreign key, and supplier due/advance is calculated from all historical purchase and payment rows (not just the recent list).

Real shopkeeper and customer accounts are still required for end-to-end acceptance testing. Do not describe these tools as fully production-verified until that testing passes.

## Specialized business workspaces

The shopkeeper dashboard now includes these vertical-specific tools:
- **Garments:** SKU, size and colour variants with per-variant price, stock, availability, edit and delete controls.
- **Jewellery:** item code, metal type, purity, gross/net weight, stone weight, metal rate, making-charge method, hallmark and certificate details. The displayed metal-plus-making estimate is indicative only and excludes stones, taxes and other charges.
- **Restaurant:** table register, menu catalogue and kitchen tickets; online orders synchronize kitchen status. The separate `restaurant-pos.html` workspace supports database-validated, idempotent POS sales, invoice numbers, discounts, an editable tax-rate field and printable receipts. Cash/UPI/card entries are payment-method records only; this POS does not collect or verify gateway payments or certify GST invoices.
- **Hotel:** room register, reservations, check-in/check-out, room-capacity checks and overlap prevention. After a booking request is accepted and a room is assigned, a customer-facing Razorpay checkout and server-side signature/captured-amount verification flow are available; live end-to-end payment acceptance remains pending.
- **Office / Company:** employee register, attendance, overlap-safe leave approvals, task assignment and guarded completion. Itemized payroll records support manually verified PF, ESI, TDS, professional-tax and other deductions/contributions; optional PF/ESI calculations use employer-confirmed eligibility plus editable rates, wage bases and limits. This is a configurable payroll aid, not a legal-compliance guarantee; TDS and state-specific items remain manual.
- **Electronics:** device register with IMEI/serial uniqueness, lifecycle and warranty dates; repair jobs and a warranty register support warranty issuance, status and claim notes. Manufacturer claim automation and external warranty-provider integrations are not included.
- **Medical:** batch-wise inventory, expiry alerts and a compliance-check register for licence, prescription, cold-chain, storage, recall and expiry reviews. Prescription capture, dispensing and full regulatory pharmacy workflows are not included.
- **Digital Seva:** application register with service/applicant details, phone, reference number, applied/expected dates, document checklist, status progression and fee/payment balance tracking.
- **Restaurant customer reservations:** shareable customer booking page, pending reservation requests, shopkeeper confirmation, table assignment, capacity validation and overlapping confirmed-table booking protection. Requests are not confirmed until the restaurant assigns a table; no deposit/payment is collected in this workflow.
- **Hotel guest booking requests:** public room-type/date request, shopkeeper review, capacity validation and atomic reservation conversion. Requests are not confirmed until a matching room is assigned; payment is offered only after approval through the separate Razorpay flow.
- **Hotel housekeeping:** room cleaning, linen-change, inspection and maintenance task register with staff assignment, due dates and guarded completion status.
- **Office HR:** salary, attendance, leave, task and payroll registers. Payroll supports itemized employee deductions and employer contributions, with optional configurable PF/ESI reference calculations; TDS and state-specific items require manual verification. Gratuity and overtime automation are not included.

Remaining specialist work includes GST-compliant tax invoicing and verified online POS settlement; automatic hotel room-status/housekeeping synchronization and live payment acceptance tests; advanced office project reporting plus gratuity/overtime automation; electronics manufacturer warranty-claim automation; medical prescription/dispensing and full regulatory workflows; and Digital Seva private document storage plus official portal integrations. All 11 core business types still require real-account end-to-end acceptance testing.

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
- Row Level Security is enabled on all 54 public application tables (verified from the production PostgreSQL catalog on 2026-11-09).
- Sensitive authorization and tenant isolation are enforced by database policies and validated RPCs.
- Supabase Cron runs subscription expiry checks hourly.
- The frontend uses a Supabase publishable key only; never expose a service-role/secret key in browser code.

## Deployment and verification status
- GitHub Pages deployment workflow is configured; the latest recorded deployment run succeeded. The public restaurant reservation page is now included in the deployment artifact and syntax checks.
- Permanent deployment safeguard: Pages deploys automatically on every push to `main`; no fixed `index.html` Git SHA is pinned, so legitimate future storefront updates cannot be blocked by an outdated baseline. Deployments are serialized (not cancelled mid-flight), and the workflow validates required pages, local links/assets, inline JavaScript, security scripts and Edge Function types before publishing.
- Inline JavaScript syntax and page element-ID reference checks passed for all 14 deployed HTML pages, including restaurant, hotel, electronics repair and digital-service customer request pages.
- Six Supabase Edge Functions are ACTIVE: subscription checkout, subscription verification, subscription webhook, shopkeeper-app generation, hotel-payment checkout and hotel-payment verification. The hotel payment source is now tracked in GitHub and CI type-checks it; the additional per-booking limiter in that source has not been deployed to production. Full Test Mode payment acceptance remains pending.
- Production snapshot on 2026-11-09: 6 Auth users, 1 active Super Admin with a verified TOTP factor, 1 active shopkeeper, 1 Grocery shop currently inactive after its one-time trial expired, 1 product, 0 orders, 0 active paid subscriptions, 0 verified payments and 1 pending/unverified payment record. Do not reactivate the shop or mark the payment paid without confirmed gateway verification. Other business types still need real shops for end-to-end browser acceptance testing.
- All 11 fixed business categories are preserved: Grocery, Daily Needs, Garments, Jewellery, Restaurant, Hotel, Office / Company, Electronics, Medical, Digital Services, and Other Businesses. The 2026-11-09 production catalogue contains 57 categories across 12 business-type values, including the separate `healthy_food_breakfast` extension. Do not remove, rename, merge or change the 11 core categories without the user's explicit permission.
- Supabase Security Advisor now reports only one remaining warning: leaked-password protection is disabled. Enable it in Auth settings before public launch if supported by the project plan. Privileged RPC implementations have been moved into the non-public `private` schema; public RPC wrappers now run as `SECURITY INVOKER` and delegate only to authenticated, authorization-checked private functions.
- Performance Advisor reports unused-index notices; do not remove indexes without reviewing real query workload.

## Important
The existing `index.html` is intentionally preserved. Do not replace it without explicit approval.


## Customer credit ledger
- Added a shop-scoped customer Udhaar ledger for credit sales, received payments and balance adjustments, with customer name/phone, date and notes.
- Shopkeepers can review recent entries, current-month credit sales and an estimated outstanding balance. The dashboard paginates through all saved entries to calculate the displayed balance, while showing the latest 60 entries for quick review. Reconcile opening balances before treating it as a full-accounting statement.
- Row-level security restricts ledger rows to the owning shop. Feature is built but requires multi-account acceptance testing before production use.

### Supplier payment query performance

- Added an index on `grocery_supplier_payments.created_by` to support creator-linked lookups and foreign-key maintenance.
- The index is applied in Supabase migration `20261031142105` (`index_grocery_supplier_payment_creator`).


See [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) for verified deployment status, payment configuration requirements, security actions and remaining launch tests.


## Production audit — 2026-11-09

- Main commit `bfe26fa284f82d81bd5595344afefbf71c40308f` passed static project validation, hotel payment Deno type-checking, reachable-history secret scanning, payment helper tests, GitHub Pages build and GitHub Pages deployment (runs 42581881283, 42581881306 and 42581880711).
- Pull request #8 added the deployed hotel payment function sources to version control, added per-booking checkout/verification rate-limit calls with fail-closed behavior, regression tests, and CI type-checking. This is source/CI synchronization; it did not deploy new Edge Function code or alter Supabase production settings.
- Current production catalog check: 54 public tables, all 54 with RLS enabled; 197 migrations applied. Security Advisor reports one warning: leaked-password protection is disabled and is plan-gated on the current Free tier. Performance Advisor reports unused-index notices; do not remove indexes without workload evidence.
- Production has one inactive Grocery shop because its one-time trial is expired; there are no active paid subscriptions or verified payments. One payment remains pending/unverified. Never manually activate the shop or mark that payment successful.
- Hotel payment endpoints are deployed, but live captured/failed/dismissed/duplicate-webhook tests remain open. The latest rate-limit hardening is in repository source and CI, not yet deployed to the production hotel endpoints.
