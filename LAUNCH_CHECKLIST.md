# Smart Business Pro — Launch Readiness Checklist

Last verified: 2026-11-02

## Verified and deployed

- GitHub Pages deployment workflow succeeded for commit `5f6958431359f23bed0c67ba29fdfe7c3035c885`.
- All 14 deployed HTML pages passed inline JavaScript syntax and duplicate-ID validation.
- All three deployed Supabase Edge Functions passed Deno type-checking:
  - `razorpay-subscription-checkout`
  - `razorpay-verify-subscription-payment`
  - `razorpay-payment-webhook`
- The approved customer storefront `index.html` remains unchanged. Its protected Git blob SHA is `854f4646215be9f0a5aaacc72ad4b7b56ac58f3e`.
- All 41 public application tables have Row Level Security enabled.
- Security Advisor has one remaining warning: leaked-password protection is disabled.
- Performance Advisor has no remaining unindexed-foreign-key or multiple-permissive-policy findings. It reports unused indexes; do not remove those until real workload data is available.
- Temporary smoke-test rows were rolled back. No smoke-test shops, reservations, payroll rows, repair jobs or service requests remain.
- Customer-facing pages now exist for restaurant reservations, hotel booking requests, electronics repair requests and Digital Seva requests.
- Digital Seva customer requests use a SECURITY INVOKER public endpoint backed by a private authorization-checked function. Anonymous users cannot read application records or directly set fees/statuses.
- Hotel booking requests are converted into reservations atomically; existing room/date overlap checks remain in force.
- Office leave approvals block overlapping approved leave. Payroll net pay is calculated in the database and paid records cannot be reopened. Office tasks support assignment, priority, due dates and guarded completion.
- Super Admin dashboard summary, shop approval and shopkeeper-account controls were exercised with temporary records in a rolled-back test transaction.
- Electronics repair job updates use guarded status transitions and preserve customer-submitted details.
- Hotel housekeeping tasks use guarded status transitions and record completion time.

## Current live-data baseline

- 4 active profiles: 2 customers, 1 shopkeeper and 1 super admin.
- 1 shop exists and is active: Grocery.
- The grocery shop is on its one-time 7-day trial, started 2026-10-31 03:53 UTC and expiring 2026-11-07 03:53 UTC.
- 1 product; 0 customer orders.
- 0 payment records; 0 paid subscriptions; 1 trial record.
- 3 active subscription plans:
  - Basic: ₹99 monthly / ₹990 yearly
  - Pro: ₹199 monthly / ₹1,990 yearly
  - Enterprise: ₹299 monthly / ₹2,990 yearly
- No live payment or paid-subscription transaction has yet been verified.
- Only the grocery category currently has an active shop. Other business-type workflows still need real category accounts for full browser acceptance testing.

## Required before public launch

### 1. Razorpay test configuration

Payments are not live until the merchant configures these Supabase Edge Function Secrets:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

Register the webhook:

`https://wqlopfftzvsjsxmrmxeq.supabase.co/functions/v1/razorpay-payment-webhook`

Subscribe to `payment.captured` and `order.paid`. Use Razorpay Test Mode first. Never put secrets in GitHub, browser code or chat.

Then test:
- Successful subscription checkout and activation.
- Failed and dismissed payments.
- Duplicate webhook deliveries.
- Delayed webhook delivery and safe retry of the same payment.
- Expired subscription access and renewal.
- Refund/support process before switching to Live Mode.

See [PAYMENT_SETUP.md](PAYMENT_SETUP.md).

### 2. Authentication security

Supabase's official documentation says leaked-password protection is available on Pro plan and above. This project is currently on the Free tier, so the Security Advisor warning is plan-gated and cannot be cleared by frontend code. Keep the warning open until the project is on an eligible plan and the Auth setting is enabled and re-verified.

### 3. Real browser acceptance tests

Use real test accounts and category-specific shops to verify:
- Customer storefront browsing, cart, checkout, delivery address and order status.
- Super Admin shop approval, shopkeeper activation, shop status and dashboard counts.
- Shopkeeper login, product/service management, stock, orders, payment and subscription gates.
- Restaurant booking request, table assignment and kitchen-ticket workflow.
- Hotel booking request, room assignment, reservation and housekeeping task workflow.
- Electronics repair request, estimate, approval, repair and delivery workflow.
- Digital Seva request, application status and fee-balance workflow.
- Office employee, attendance, leave and manual payroll workflow.
- Garment variants, jewellery details, medical batch/expiry and all other category-specific screens.
- Android mobile layout, form validation, browser refresh and network-failure handling.

### 4. Remaining specialist scope

These items are not represented as completed:

- Restaurant POS, tax invoices and payment settlement.
- Hotel online payment collection and automatic room-status/housekeeping synchronization.
- Office task/project workflows and statutory payroll calculations (TDS, PF, ESI, gratuity and overtime).
- Electronics warranty-claim automation.
- Medical prescription/dispensing and regulatory workflows. The current medical module is inventory support only.
- Digital Seva private document storage and official portal integrations. The public form intentionally does not collect identity numbers, OTPs or document scans.
- Full end-to-end acceptance testing for all 11 business types.

## Safety and data-preservation notes

- Do not replace or edit the protected `index.html` baseline without explicit approval.
- Database smoke tests use temporary records inside transactions and roll them back.
- Do not store payment secrets in repository files or public HTML.
- Do not collect Aadhaar/PAN numbers, OTPs, passwords or sensitive document scans through public forms.
- Office payroll is a manual record and does not calculate statutory deductions.
- Customer hotel/restaurant requests are not confirmed until the shopkeeper accepts them; those request pages do not collect deposits.


## Automated checks and current security gate — 2026-11-02

- Static validation now also checks local page links/assets, `target="_blank"` opener safety, and common secret/key patterns in public HTML/JS. Latest validator commit: `4bdedaa0c065102fc55555c7d9b12525dd08033b`; confirm the matching GitHub Actions run before considering the new checks complete.
- Current Supabase catalog snapshot: 41 public tables; all 41 have RLS enabled and policies. No RLS-disabled table, policy-less RLS table, or UPDATE policy missing WITH CHECK was found in the targeted query.
- Seven public/anon mutation policies exist; they are structurally constrained to account ownership/admin checks or bounded customer-request inserts, and direct order inserts are denied. Negative API tests remain required.
- Supabase Free tier currently blocks leaked-password protection (official docs: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). The current Security Advisor warning remains a launch security gate.


## Static validation result — 2026-11-02

- Expanded static validation passed on commit `ab83f827e611403b6d786fddef5d0a90669a9a31`, GitHub Actions run `41377126260`: **283 checks across 14 HTML pages, 1 public script and 11 business categories**.
- The new checks cover local links/assets, target=_blank opener safety and common private credential patterns in public HTML/JS, in addition to the earlier syntax, duplicate-ID and category checks.
- GitHub Pages deployment/build for this exact commit was pending at the time of this update. Do not assume the latest code is live until those runs succeed.
