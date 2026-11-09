# Smart Business Pro — Launch Readiness Checklist

Last verified: 2026-11-09

## Verified and deployed

- GitHub Pages deployment workflow succeeded for latest verified website commit `c244dcf1b3e056d22d702f7829c836e00aa8fb05`.
- All 14 deployed HTML pages passed inline JavaScript syntax and duplicate-ID validation.
- Six Supabase Edge Functions are ACTIVE: the three subscription payment functions, `generate-shopkeeper-app`, `hotel-payment-checkout` and `hotel-payment-verify`. The latest main-branch CI type-checked all deployed function sources.
- The approved customer storefront `index.html` remains unchanged. Its protected Git blob SHA is `854f4646215be9f0a5aaacc72ad4b7b56ac58f3e`.
- All 54 public application tables have Row Level Security enabled (production query on 2026-11-09: 54 enabled, 0 disabled); 197 migrations are applied.
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

- 6 Auth users; 1 active Super Admin with a verified TOTP factor; 1 active shopkeeper.
- 1 Grocery shop exists, currently inactive because its one-time 7-day trial is expired; 0 active trials.
- 1 product; 0 customer orders; 0 active paid subscriptions.
- 0 verified payments; 1 Razorpay payment record remains `pending` and `verified=false`.
- 3 active subscription plans:
  - Basic: ₹99 monthly / ₹990 yearly
  - Pro: ₹199 monthly / ₹1,990 yearly
  - Enterprise: ₹299 monthly / ₹2,990 yearly
- No live payment or paid-subscription transaction has yet been verified.
- No shop is currently active. Other business-type workflows also need real category accounts for full browser acceptance testing.

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

- GST-compliant restaurant tax invoices and verified online POS settlement; the basic POS invoice/receipt workflow exists, but UPI/card selection only records a payment method.
- Automatic hotel room-status/housekeeping synchronization and live end-to-end acceptance of the deployed hotel Razorpay payment flow.
- Advanced office project reporting, gratuity/overtime automation; PF/ESI reference calculations and itemized payroll are implemented but require employer-confirmed rules and professional review; TDS remains manual.
- Electronics manufacturer warranty-claim automation; warranty register, issuance and claim notes are implemented.
- Medical prescription/dispensing and full regulatory workflows; inventory and batch-compliance checks are implemented.
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


## Execution update — 2026-11-04

### Latest completed deployment
- GitHub Pages is deployed successfully from main commit `c244dcf1b3e056d22d702f7829c836e00aa8fb05`. The Pages build/deploy workflow and the custom deploy workflow both completed successfully.
- Static project validation passed on this commit, including the reachable Git-history secret scan, HTML/inline-JavaScript validation, payment helper tests and category checks.
- All three production Razorpay Edge Functions passed Deno type-checking in the deployment workflow. `razorpay-subscription-checkout` is deployed at version 18 and `razorpay-verify-subscription-payment` at version 14.
- `sitemap.xml` now lists 12 public URLs. Private workspace `shopkeeper.html` has `noindex,nofollow,noarchive`; `owner.html` remains noindex. Private/admin pages are not listed in the sitemap.
- The approved customer storefront `index.html` was not modified by the latest fixes. Existing database rows and the pending Razorpay transaction were preserved.

### Catalogue and migration status
- Added 200 unique, category-specific starter catalogue templates for each of the 11 business types: **2,200 total**. The shopkeeper dashboard loads the catalogue matching the selected shop's immutable `business_type`.
- Bulk imports remain safe drafts: zero stock, unavailable to customers, no photos or live-price assumptions. Shopkeepers must verify prices, stock and photos before publishing. Existing shop inventory is not overwritten.
- `catalogue.html` browses all 11 category catalogues; automated checks enforce exactly 200 unique entries per category.
- Restored all 39 previously missing applied migration source files directly from `supabase_migrations.schema_migrations.statements`. Production migration history and repository source match: **188 applied / 188 source files; zero missing or extra versions**.
- Owner-profile verification uses SECURITY INVOKER public wrappers; privileged implementation remains in the private schema; issuing a QR requires active Super Admin + AAL2 + verified TOTP. Browser roles have no token-table access and an explicit deny policy is installed.
- Added missing Grocery starter-category rows required for product-category matching.

### Payment reconciliation status
- Existing payment reference: ₹99 INR, payment row `16699710-ccb0-4d42-93fe-66ff2c80e896`, Razorpay order `order_Tva9s7C35qvxmA`.
- At the latest database check, this record is still `pending`, `verified=false`, with no stored Razorpay payment ID. No paid subscription has been activated.
- Edge Function version 13 now supports authenticated server-side reconciliation against the existing Razorpay order's payments API. The shopkeeper checkout first checks this saved order; a captured matching payment can be applied without opening checkout again. If no payment is captured, it reuses the existing order. It never creates a replacement order during reconciliation.
- This reconciliation path is deployed but still needs an authenticated user-session invocation against Razorpay. Do not claim the payment is captured until the database shows `verified=true` after gateway confirmation. Do not pay again merely to test recovery.

### Current production gates (not claimed complete)
- Live database has 1 active shop (Grocery) and 1 live product. The 2,200 entries are templates, not automatically published inventory. The current shop's existing `Toor daal` item is retained; duplicate starter import is skipped.
- Supabase Security Advisor reports one warning: leaked-password protection is disabled and is plan-gated on the current Free tier. Enable it after moving to an eligible plan and re-verify.
- Performance Advisor reports unused-index notices. Do not drop indexes without workload evidence.
- One active Super Admin account has a verified TOTP factor. Auth logs record a successful TOTP verification and MFA login on 2026-11-03 23:54:53 UTC; a fresh production-domain browser login and Owner dashboard access still need confirmation.
- Real browser acceptance testing for all 11 categories, end-to-end Razorpay captured/failed/dismissed/duplicate-webhook cases, and recovery/backup restore tests remain open. No physical Android/browser tests are claimed.
- Medical workflows remain inventory support only; prescription/dispensing and regulatory workflows are not complete. Other specialist scope listed above remains pending.
- Preserve the existing customer storefront and production data. Never manually mark a payment successful or activate a subscription without gateway verification.


## Production verification update — 2026-11-09

- Production database read-only audit: 54 public tables, all with RLS enabled; 197 migrations applied and 197 exact-version SQL source files in GitHub (zero missing/extra after PR #9); 57 catalogue categories across 12 business-type values (the 11 core categories remain preserved, plus a separate `healthy_food_breakfast` extension).
- Live state: 6 Auth users; 1 active Super Admin with verified TOTP; 1 active shopkeeper; 1 Grocery shop inactive after trial expiry; 1 product; 0 orders; 0 active paid subscriptions; 0 verified payments; 1 pending/unverified payment.
- Six Edge Functions report ACTIVE. Subscription checkout/verification/webhook and shopkeeper-app generation are deployed; hotel payment checkout/verification are also deployed. Their live end-to-end payment acceptance is not yet verified.
- PR #8 merged to main as `bfe26fa284f82d81bd5595344afefbf71c40308f`. It adds the two deployed hotel payment sources to version control, per-booking rate-limit calls (5 checkout and 10 verification attempts per rolling 15 minutes, fail-closed), regression tests and CI Deno type-checking. This PR did not deploy updated Edge Function code or change Supabase production settings.
- PR #9 merged as `360d2bdc2ac614fc13680975278e06690c4e675b`: six exact production migration sources were restored and three duplicate timestamp filenames were reconciled. Production migration history was not changed. The source comparison now confirms 197 applied versions, 197 repository SQL files, zero missing and zero extra. Static validation and Pages deployment succeeded on the merge commit.
- GitHub Actions run 42581881283: static project validation, hotel payment Deno type-check, reachable-history secret scan, static page/category checks and payment helper tests succeeded. Runs 42581881306 and 42581880711: custom deployment and GitHub Pages build/deployment succeeded.
- Security Advisor: one warning remains, leaked-password protection disabled; this setting is plan-gated on the current Free tier. Performance Advisor reports unused indexes; no index was dropped.
- Launch remains blocked on real Razorpay Test Mode acceptance (including existing pending-payment reconciliation), production hotel endpoint rate-limit deployment/review, fresh Super Admin MFA login and sensitive-action tests, all-11-category real-account browser acceptance, and backup/recovery restore evidence. Do not manually activate the expired shop or mark any payment successful.
