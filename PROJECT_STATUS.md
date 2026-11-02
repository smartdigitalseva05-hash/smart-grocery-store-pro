# Smart Business Pro — Project Status


## OWNER DIRECTIVE — SECURITY-FIRST EXECUTION LOCK (2026-11-02)

**Permanent project priority:** The 10-feature Security Shield is the only active implementation module until all ten controls are implemented, independently verified, and deployment/security review is complete. Do not start or expand category, shopkeeper, Owner dashboard, payment UI, analytics, or other feature work before that gate passes. Only security work and safe maintenance/regression fixes are allowed during this lock.

**Do not confuse documentation or a visible UI with a working security control.** A feature may be marked Completed only with implementation evidence plus passing automated/API tests for its acceptance criteria. Keep blocked/plan-gated items open and state the dependency. Do not claim 10/10 until every row below is Completed.

| # | Mandatory security feature | Current evidence-based status (2026-11-02) | Remaining completion gate |
|---|---|---|---|
| 1 | Zero-Trust Security | **In Progress** | SQL role tests cover two-tenant shops/products/orders/payments/Storage and seven additional business-module tables; owner A/B each saw only their own module rows, unrelated customer saw zero. Complete remaining HTTP/PostgREST tests and remaining RPCs. |
| 2 | Super Admin Lock | **In Progress** | Owner TOTP enrollment/challenge UI exists and `private.is_super_admin()` requires active Super Admin + JWT AAL2 + a currently verified TOTP factor. No live factor is enrolled yet; complete real enrollment, fresh-session verification, recovery and sensitive-operation HTTP tests. |
| 3 | Database Fortress | **In Progress** | 41/41 public tables have RLS and policies. Two-tenant SQL isolation passes across Electronics, Hotel, Office and Restaurant operational tables; anonymous catalog reads are column-allowlisted; shopkeeper grants are least-privilege; private limiter tables are deny-all. Migration `20261102080828` now adds a tenant-scoped `grocery_expenses` UPDATE policy with `WITH CHECK` and an immutable shop/creator trigger; catalog verification confirms both are installed. Complete remaining table/API matrix and HTTP/PostgREST tests. |
| 4 | Anti-Brute-Force | **In Progress** | Concurrency-safe sliding 60-minute limits cover public intake forms. Payment endpoints now enforce account-based 15-minute limits: 5 checkout attempts and 10 verification attempts; sequential threshold tests rejected attempts 6 and 11. Still implement/test login/Auth limits, IP/device controls, concurrent load and recovery. |
| 5 | Secret Vault | **In Progress** | Current-tree scan and automated reachable-Git-history scan cover Supabase, Razorpay, AWS, Google, GitHub, Slack and private-key patterns; no findings. Selected secret-file paths have zero commits. External credential inventory and rotation review remain. |
| 6 | Attack Protection | **In Progress** | Checkout and verification CORS allow only `https://smartdigitalseva05-hash.github.io`; both enforce JSON content type, 16 KiB streamed body limits and account-based rate limits. Checkout v12 and verification v10 are deployed with JWT required. Broad server-side validation/XSS/CSRF/SQLi/IDOR/upload/redirect and live disallowed-origin HTTP tests remain. |
| 7 | Real-Time Alerts | **In Progress** | Owner dashboard now subscribes to `audit_logs` INSERT events through Supabase Realtime; publication enabled and SELECT is AAL2+verified-TOTP RLS-gated. Live connection awaits real Owner TOTP enrollment; failed-login alerts and out-of-app delivery remain open. |
| 8 | Backup & Recovery | **Blocked (managed daily backups on Free tier); manual export path In Progress** | Supabase docs say daily managed backups are Pro/Team/Enterprise; Free projects must use CLI db dump and off-site exports. Database exports do not include Storage objects. Build and verify manual DB + Storage backup and restore. |
| 9 | Audit Trail | **In Progress** | Trigger-based audit logging now covers 31 public tables, including profiles, shops and shop_trials security changes, plus orders/payments, grocery finance, catalogue, inventory, customer address metadata, bookings, staff and platform settings. Sensitive identity/shop audit fields are explicitly allowlisted; direct audit writes are denied. Continue remaining mutation paths, retention and alert linkage. |
| 10 | Payment Shield | **In Progress** | Database negative/amount-mismatch and idempotent activation tests passed; webhook v9 caps raw bodies at 1 MiB and verifies exact-byte HMAC. Checkout v12 and verification v10 require JWT, allow only the production origin, enforce JSON/16 KiB limits and account rate limits (5 checkout / 10 verify per 15 minutes). Still test real signed deliveries, invalid signatures, replay/duplicate delivery and concurrent payment flows. |

### Verified baseline (not a 10/10 completion claim)
- GitHub Actions static validator passed **283 checks** across 14 HTML pages, 1 public JS file and all 11 business categories on commit ab83f827e611403b6d786fddef5d0a90669a9a31 (run 41377126260). This is static validation, not end-to-end security proof.
- Supabase catalog audit found **41/41 public tables with RLS enabled and at least one policy**; targeted structural scan found no UPDATE policy missing WITH CHECK. Role-based negative API tests remain required.
- Three Razorpay Edge Functions are active: checkout v12 and verification v10 require JWT; webhook v9 uses verify_jwt=false and verifies Razorpay raw-body HMAC. Checkout and verification restrict CORS to the confirmed GitHub Pages origin, enforce JSON/16 KiB body limits and use server-side account rate limiting.
- Supabase Security Advisor still reports leaked-password protection disabled. Current project tier is Free; official Supabase docs state this control is plan-gated to Pro and above: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- The customer storefront index.html remains protected and must not be edited as part of this work unless the Owner explicitly approves it.



### Security execution update — 2026-11-02 08:12 UTC
- Applied and verified migration `20261102080828` (`harden_grocery_expense_update_tenant_integrity`): `grocery_expenses_update` is now scoped to an active Grocery shop and includes `WITH CHECK`; a SECURITY INVOKER trigger prevents authenticated changes to `shop_id` or `created_by`. The trigger is installed with an empty search path.
- Restricted the checkout and payment-verification Edge Function CORS allow-origin from `*` to the confirmed production origin `https://smartdigitalseva05-hash.github.io`, with `Vary: Origin`. Both now run the repository's 16 KiB streaming body-limit helper. Deployed checkout v11 and verification v9; both remain `verify_jwt=true`.
- GitHub Actions static validation passed on commit `ee80b0eaf3710619db23e02c983be1c2681db478`; the Pages workflow's Deno type-check, website validation and deployment all passed. The customer storefront `index.html` was not changed.
- MFA audit still finds zero verified TOTP factors for the active Super Admin account; Super Admin Lock remains incomplete until the Owner enrolls and verifies a factor and the fresh-session/API acceptance tests pass. Security Advisor still reports leaked-password protection disabled; current Free tier plan-gates this control.



### Payment endpoint abuse-control verification — 2026-11-02 08:19 UTC
- Applied migration `20261102081537`: private payment rate-limit event storage plus a server-only RPC. Checkout is limited to 5 requests per account per rolling 15 minutes; verification is limited to 10. Sequential SQL threshold tests confirmed request 6 and request 11 are rejected with `PT429`.
- Applied migration `20261102081910`: explicit deny-all RLS policy for anon/authenticated on the private rate-limit table. Security Advisor now reports only the plan-gated leaked-password-protection warning; the private-table no-policy INFO finding is cleared.
- Checkout v12 and verification v10 now call the rate-limit RPC using server-side credentials, fail closed if the check is unavailable, require JSON, and retain JWT verification, exact-origin CORS and 16 KiB request limits.
- Static regression tests and GitHub Pages deployment passed on commit `1c38e319658dcf7bee61573fb5ba9d7907794b4e`. Concurrent-load and live HTTP tests remain open. Supabase Auth login limits and IP/device controls also remain open.
- The matching SQL source files for migrations `20261102081352`, `20261102081537` and `20261102081910` still need to be synchronized into the GitHub migrations directory; live Supabase migration history records them.

### Execution order while the lock is active
1. Complete and test Super Admin Lock and Zero-Trust server authorization.
2. Complete Database Fortress role/tenant isolation tests and remediate findings.
3. Implement/test Anti-Brute-Force and Attack Protection, including safe CORS allowlisting.
4. Complete Secret Vault and credential-history/rotation review.
5. Implement/test Real-Time Alerts and Audit Trail integrity/coverage.
6. Complete Payment Shield negative/replay/concurrency tests.
7. Verify backup capability and perform a safe restore drill; resolve plan-gated controls explicitly.
8. Run full regression, Security Advisor, static/API suite and deployment verification; only then mark Security Shield 10/10 Completed and unlock the next project module.

**No destructive production changes, mass session revocation, payment behavior changes, broad CORS restrictions, or lockout rules may be deployed without a reviewed recovery path and verified test coverage. Preserve existing user/business/payment data.**

**Last updated:** 2026-11-02

## Current active work

**Active module — Security Shield (10 mandatory controls).**

The execution lock remains active. Only Security Shield implementation, verification, safe maintenance and regression work may proceed. Business category and other feature modules remain paused until all 10 controls meet their evidence gates.

## 11 Business Categories

1. Grocery
2. Daily Needs
3. Garments
4. Jewellery
5. Restaurant
6. Hotel
7. Office / Company
8. Electronics
9. Medical
10. Digital Services
11. Other Businesses

## Status snapshot

### Completed so far
- The 11 category names/cards are listed in the portal page.
- Category names/basic descriptions are present in the category listing.
- Category options/filters were previously found in the shop registration, customer storefront, owner panel, and showcase pages.
- Portal category-card update was committed in `portal.html` (commit: `15a8fc5c786a7a4f667643a94dba372b898f2921`).
- Shop registration form already contains all 11 business type options and stores the selected value in `shops.business_type`.
- Shopkeeper workspace already contains category-specific workspace definitions and specialized workflows for several categories; these should be completed/reviewed rather than rebuilt.
- Fixed a registration-flow blocker: an account with one existing shop was previously prevented from submitting another shop application. `apply-shop.html` now shows existing application count but keeps the registration form available, matching the multi-shop selector in the shopkeeper workspace (commit: `a8e3cf082b931f8b01942c749a6f863ace0b1591`).

### Database mapping note (2026-11-01)
- The `shops.business_type` field stores the business category key (for example, `grocery`); the shop registration form offers all 11 keys.
- The public `categories` table is a product/menu/service category catalogue (examples: Staples, Men's Wear, Main Course, Prescription Medicines), not the master list of the 11 business types. Do not confuse these two levels.
- Current shop data query shows 1 registered shop and it is `grocery`. The other 10 business types have no registered shop rows yet, so their real shop flows cannot be verified from live shop data.
- Next category-module implementation task: formalize and enforce a single 11-key business-type mapping across registration, owner filters, shopkeeper workspace routing, and customer discovery, while keeping product categories scoped to the relevant shop/business type.

### Not yet confirmed as complete
- Category-aware registration for all 11 types exists as a shared form; confirm each type is persisted and correctly routed. Separate per-category forms are not required unless the product design calls for them.
- Category-specific shop dashboard and permissions.
- Category-wise product add/edit/delete.
- Category-wise order management and order status.
- Owner panel category controls and management.
- Customer-facing category-wise shop/product discovery.
- End-to-end testing of all 11 category flows.

**Important:** A visible category card or dropdown option does not mean that category's complete business system is implemented. Do not mark a module complete until its functionality is implemented and checked.

## Security & Protection Module — audit started

### Read-only audit findings (2026-11-01)
- Supabase Security Advisor reports **1 warning**: leaked-password protection is disabled. Remediation: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Database inspection on 2026-11-02 found **41 public tables**; all 41 have RLS enabled and at least one RLS policy. Follow-up catalog checks found 0 tables with RLS disabled, 0 RLS-enabled tables without a policy, and 0 UPDATE policies missing WITH CHECK. Seven public/anon mutation policies were inspected: each is scoped to the authenticated row owner or private Super Admin check, or is a constrained customer-request INSERT; direct order INSERT is explicitly denied. These structural checks still require negative role-based API tests. This is a positive baseline, not proof that every policy is correct.
- Three Razorpay Edge Functions are active. Checkout and payment verification require JWT. The public webhook has JWT verification disabled but its inspected handler validates the raw-body Razorpay HMAC-SHA256 signature using a constant-time comparison, then checks captured status, INR currency, order match, and exact amount before applying payment. Replay/idempotency behavior still needs dedicated tests.
- A client-side `password-security.js` checks for passwords of at least 12 characters and queries the Have I Been Pwned range API using the first five SHA-1 hash characters. This client-side check is supplementary and does not replace Supabase Auth protections.
- No database or Auth settings were changed during this audit.

### Security work still pending
1. Enable Supabase Auth leaked-password protection in Auth settings (dashboard setting; not changed by this audit).
2. Review every RLS policy for cross-shop data leakage, role escalation, public reads/writes, and correct UPDATE `USING` plus `WITH CHECK` rules.
3. Webhook HMAC signature and amount/currency checks are present in code; still test invalid signatures, duplicate delivery, event replay, concurrent delivery, and subscription activation idempotency.
4. Verify that service-role/secret keys never appear in browser files or Git history; keep secrets only in server-side Edge Function secrets.
5. Review login/session handling, password reset, owner/shopkeeper role assignment, and account recovery.
6. Review Storage bucket policies, file upload restrictions, and private customer documents.
7. Add/verify audit logging, rate limiting, input validation, abuse protection, and backup/restore process.
8. Re-run Supabase Security Advisor and perform role-based access tests before marking Security Module complete.

## Development order

1. Security Shield — complete and independently verify all 10 controls; no other feature work before the gate passes.
2. Full security regression, Advisor review, backup/restore evidence and deployment verification.
3. Only after 10/10 is formally Completed, resume the business-category and other product modules.
3. Registration Module — save each shop with the correct category.
4. Shop Dashboard Module — show the correct tools for each shop.
5. Product Module — category/shop-specific product management.
6. Order Module — customer orders and status handling.
7. Customer Module — browse shops and products by category.
8. Owner Module — manage all shops and categories.
9. Payment Module — Razorpay subscription/payment flow.
10. Testing Module — test each module and all 11 category flows.

## Module completion checklist

A module is complete only when:
- Its required features are implemented, not just shown in the UI.
- Access permissions and data isolation are checked where relevant.
- Existing working pages and data remain intact.
- The feature is verified with appropriate tests.
- This file is updated with the exact completed and pending items.

## Project safety rules

- Do not modify `index.html` unless the owner explicitly asks.
- Preserve existing data and working features.
- Work module by module: implement, then verify, then move to the next module.
- Safe independent read-only checks may run in parallel; writes to the same file/table must be sequential.
- Do not call a module complete based only on its visual design.
- Record each meaningful progress update in this file.

## Super Admin Business Website Links (2026-11-01)

- Added a **Business Website Links** panel to `owner.html` without changing `index.html` or existing database records.
- The panel displays buttons for all 11 configured business types, with registered-store counts. It also detects additional business_type keys found in registered shops, so new category keys can appear without adding another fixed button manually.
- Selecting a category lists its registered stores. A store receives an **Open Website** link only when `status = active` and `is_active = true`; the link opens the existing customer storefront filtered to that shop using `index.html?shop_id=<shop UUID>`.
- Inactive/pending shops are shown as not live, without a misleading working link. Active links can also be copied.
- Verified from schema and storefront code: `shops` has no dedicated website URL column; the existing customer storefront already supports `shop_id` filtering. Therefore the new links are shop-specific storefront URLs on the platform, not independently hosted custom domains.
- Owner panel commits: `abdfd310ef8f852781a1d58edcdcc30523475ff1` (feature) and `632854f7dc04f140c68e5cdccf86f598870d0548` (dynamic category label polish).
- Browser end-to-end testing and live GitHub Pages deployment confirmation are still pending.

## Category-wise Super Admin Controls and Global Search (2026-11-01)

- Replaced the earlier Business Website Links-only panel with **Category-wise Business Control** in `owner.html`.
- The panel is rendered inside the existing Super Admin dashboard, which is only revealed after the authenticated Owner flow and the database `owner_dashboard_summary` permission check.
- Added one button per configured business category plus **All Businesses**. Counts on buttons show registered stores in each category; unknown/new `business_type` keys are detected and get their own button.
- Added global search across shop name, city, phone, status, category and owner display name. With **All Businesses** selected, results cover every category. Summary counters show total businesses, active businesses, category count and filtered result count.
- Each shop card includes its category, owner and status, a live storefront link when active, and Owner RPC controls for shopkeeper approval (where applicable), activation, setting inactive, and suspension. Activation still relies on the existing verified-subscription server rule; no payment or subscription is fabricated.
- All changes are in `owner.html`; `index.html` and database records/schema were not changed.
- Commit: `3f619c473268f410c7c1aacd9da1e7aa15fe2f88`.
- Static source checks passed for the new panel, global search, counters, category buttons and existing Owner RPC calls. GitHub Actions static validation now passes for the current commit; the GitHub Pages deployment workflow is being monitored separately.


## Automated Verification Policy (2026-11-01)

- Owner instruction: physical/mobile testing by the owner is not a required project gate. Use code review, static validation, automated tests, and server/API checks instead.
- Do not promise literal zero defects; record exactly which automated checks passed and which external/runtime checks remain.
- Added `scripts/validate-static.mjs` and `.github/workflows/static-validation.yml`. On every push to main and pull request, GitHub Actions checks required HTML pages, duplicate element IDs, inline JavaScript syntax, and the 11 business category keys across registration, shopkeeper workspace, Owner controls, and portal cards.
- Static validation passed on commit `e141bb73cb9941c5c76f1b23eca208946ad34e71` (workflow run `41324387456`).
- The separate `Deploy static website to GitHub Pages` workflow also succeeded on the same commit (run `41324387454`). The GitHub Pages build/deployment run is still being checked; do not mark the live deployment confirmed until it completes successfully.
- A prior source-only pass compiled the inline JavaScript in 13 HTML/JS files and found no duplicate IDs. This is syntax validation only, not proof that every user journey or database policy works at runtime.

## Current Category Module Gaps (reconfirmed 2026-11-01)

- The 11 category keys are present in registration, shopkeeper workspace configuration, Owner category controls, and portal cards, and the static CI now guards against accidental removal.
- Category-specific workspace configurations exist, but that alone does not prove every specialized product/order/customer workflow is complete for every business type.
- The live database previously contained only one registered Grocery shop; the other 10 categories have no live shop records to exercise their data flows against.
- Continue auditing the real forms, database tables, RLS policies, customer discovery and order handling per category. Keep the Category Module in progress until the actual feature coverage and permissions are verified.


## Role-based Powerful Search & Quick Finder (2026-11-01)

- Added a separate **Owner Quick Finder** to `owner.html` and **Shopkeeper Quick Finder** to `shopkeeper.html`.
- Both finders are shown only inside their respective authenticated workspace header; each searches only its own role's visible workspace content. The Shopkeeper finder does not index or expose the Owner dashboard or Owner-only controls.
- Search indexes visible headings, buttons, links, form labels, input placeholders and accessible select labels. Results show the containing section name; selecting a result scrolls to it, highlights it briefly and focuses controls where appropriate.
- Added keyboard shortcut **Ctrl + K** (also Cmd + K on supported devices) to open the finder, plus Escape and outside-click dismissal.
- Hidden category panels and hidden dashboard sections are excluded from results until visible. No database queries, permissions, shop data or payment logic were changed.
- Files changed: `owner.html`, `shopkeeper.html`. `index.html` remains untouched.
- Initial source validation: both updated files have valid inline JavaScript syntax and no duplicate HTML IDs. The repository's GitHub Actions static validation workflow will also check the latest commit.
- Scope note: this is a navigation/tool finder, not a cross-database search. Owner's existing All Businesses global shop search remains the place to find registered stores. Shopkeeper product/order data remains within its existing workspace lists and access rules.


## Owner Command Center (2026-11-01)

- Added a centralized **Owner Command Center** launchpad near the top of the authenticated Super Admin dashboard in `owner.html`.
- It links directly to the existing protected controls: business approvals/status, all-category business control and global search, shopkeeper account management, product category management, payment verification, and security/audit activity.
- Added stable section anchors to those existing control panels so the Owner can jump directly to the relevant area from one place.
- This is a central navigation/launchpad layer over existing features; it does not falsely claim that unimplemented customer, order, global product CRUD, or platform configuration controls now exist. Those remain future work after their backend permissions and workflows are implemented.
- Existing Supabase Owner authorization, RPC checks, RLS policies, subscription verification rules, and audit logging were not bypassed or weakened. No database records/schema or `index.html` were changed.
- Owner page commit: `9f089400d6a43ec8bad70eb06aaa9ec4f4e67fd9`.
- Automated validation/deployment for this commit must be checked before calling the updated page live.


## Live Work Tracker & Status Rules (2026-11-01)

**Status rule requested by Owner:** Every meaningful task must be recorded here. Never leave unfinished work looking completed. Update this tracker after implementation and verification.

| Work item | Status | Evidence / remaining work |
|---|---|---|
| Owner Command Center navigation hub | **Completed** | Present in `owner.html`; six links navigate to existing protected sections. Source commit: `9f089400d6a43ec8bad70eb06aaa9ec4f4e67fd9`. |
| Owner Command Center deployment | **Completed** | GitHub Pages deployment for commit `5cb669aeedf1644a3bfcda43a1de2083c6ccf471` succeeded (run `41325286042`); this commit includes the Command Center and status documentation. |
| Owner Command Center full-control coverage | **Pending** | Hub is currently a navigation layer, not a complete all-platform control system. Customer administration, global product CRUD, global order management, platform configuration and further account controls still need verified backend operations and permission checks. |
| Category Module | **In Progress** | 11 category keys and navigation/configuration exist; full category-specific product/order/customer workflows and data isolation remain to be verified. |
| Security & Protection Module | **In Progress** | RLS is enabled on all 40 inspected public tables, but policy correctness, leaked-password protection, secret exposure, storage controls and webhook replay/idempotency tests remain pending. |
| Registration Module | **In Progress** | Multi-shop registration blocker fixed; full category persistence and account/role edge cases remain to be verified. |
| Shop Dashboard Module | **In Progress** | Category-aware workspace exists; full feature and permission coverage remains to be audited. |
| Product Module | **Pending** | Complete cross-category add/edit/delete, stock and shop-isolation checks. |
| Order Module | **Pending** | Complete customer ordering, shopkeeper fulfilment, status transitions and owner oversight. |
| Customer Module | **Pending** | Complete category/shop discovery, customer account controls and privacy checks. |
| Owner Module (beyond current hub) | **In Progress** | Existing shop, shopkeeper, catalog, payment and audit sections are available; missing global controls listed above remain pending. |
| Payment Module | **In Progress** | Razorpay checkout/verification/webhook functions exist; replay, duplicate and concurrency/idempotency tests remain pending. |
| Automated Testing Module | **In Progress** | Static GitHub Actions validation exists; broader API, authorization, regression and workflow tests remain pending. |

### Required status meanings
- **Pending:** not started, or required implementation has not yet been done.
- **In Progress:** implementation or verification is underway.
- **Completed:** implementation is present and the relevant automated/static/API checks passed; deployment is confirmed when a live page is involved.
- **Deployment Pending:** code is committed but the latest relevant deployment has not succeeded yet.
- **Blocked:** work cannot proceed until a stated dependency is resolved.

### Update discipline
1. Before starting a new task, list it as **Pending** or **In Progress**.
2. After coding, keep it **In Progress** until verification is complete.
3. Record the exact checks and commit/run evidence before marking **Completed**.
4. Keep incomplete sub-features explicitly **Pending**, even when their parent dashboard or module has a visible UI.
5. Do not mark physical user testing as required; use code review, automated/static tests and server/API checks as the project verification approach.
6. Keep `index.html` and existing database records safe unless the Owner explicitly requests a change.


## Owner Command Center — implementation audit update (2026-11-01)

**Overall Owner Command Center status: In Progress (not fully completed).**

### Verified backend capabilities
- Owner dashboard summary is protected by an explicit active Super Admin check in `owner_dashboard_summary()`.
- `shops` policies allow active Super Admin read/update/delete; shop activation and shopkeeper status changes already route through Owner RPC functions.
- `profiles` SELECT and UPDATE policies include the private Super Admin check.
- `products` SELECT/INSERT/UPDATE/DELETE policies include the private Super Admin check (product mutation still needs careful UI validation and audit review before exposing global bulk actions).
- `orders` SELECT policy includes the private Super Admin check, but direct INSERT is explicitly denied and no Owner UPDATE policy appeared in the inspected policy set. Do not add order status mutation controls until a dedicated, audited Owner RPC and transition rules are verified.
- `payments` SELECT policy includes the private Super Admin check; successful payment application uses the existing `verify_payment_and_activate` RPC.
- `audit_logs` SELECT is protected by the private Super Admin check.

### Remaining Owner Command Center work — explicitly Pending
1. Global customer directory with safe fields, search and account controls; do not expose unnecessary customer PII.
2. Global order console: search/filter and detail view; status changes require a dedicated server-side Owner RPC with allowed transition checks and audit events.
3. Global product console: search/filter and safe per-product actions; bulk changes require explicit server-side authorization and audit.
4. Platform settings console: only expose settings backed by a validated schema/RPC; no client-only fake settings.
5. Unified audit trail with filters and pagination; verify no secrets or excessive personal data are rendered.
6. Final role/access tests for Owner, Shopkeeper, Customer and signed-out users, plus static validation and successful deployment.

### Security caveat
- Security Advisor still reports leaked-password protection disabled. This is a project-level Auth setting and remains Pending; do not claim Security Module complete.
- No schema, RLS policy, Auth setting, payment record, customer record or existing shop record was changed in this audit.


## All-in-One Super Admin Control & Search (2026-11-01)

- Added one prominent **All-in-One Control** button to the authenticated Owner header; it opens the centralized searchable control directory.
- Search directory includes available sections for Business & 11 categories, Shopkeeper Accounts, Product Categories, Payments & Subscriptions, and Security & Audit Logs. Selecting an available result jumps to its existing Owner control section.
- Directory also indexes Customer Controls, Global Order Controls, Global Product/Inventory Controls, Platform Settings, and Reports. These are explicitly labelled **Pending** and disabled in the launcher until their secure backend workflows are implemented; no fake controls or unauthorized actions are exposed.
- Search matches feature names, alternate keywords and control area. Ctrl+K / Cmd+K opens the same launcher; Escape closes it.
- Source commit: `a41ed38a04092de760d96bf36538d4fed8581a40`.
- Static content verification passed: one All-in-One button, searchable modal, available/pending labels, disabled pending entries, five pending feature groups, and keyboard shortcut are present.
- Overall All-in-One control feature status: **In Progress** until GitHub static validation and Pages deployment for this change succeed. The launcher/navigation layer is implemented; global customer/order/product operations and platform settings remain **Pending**.


## Owner All-in-One Control — Customer Directory (2026-11-01)

- Added a Customer Directory panel to `owner.html`, linked from the Owner Command Center and searchable through the All-in-One Control launcher.
- Directory loads up to 500 customer profiles ordered newest first and filters locally by customer name or active/blocked status.
- Privacy scope: displays only profile display name, account status and join date. It does not display phone, email, address, payment information, order contents or customer documents.
- Read-only by design: no customer block/delete/role-change action was added because a dedicated audited Owner backend operation and policy review are not yet verified.
- Source commits: `9d2602e29755d2aa79aa78f50ac4e79cb4940325` and `1c6229ddfe6dfe01266fe4a55dd809eddc0e770f`.
- Customer Directory implementation: **In Progress** pending static validation, deployment and confirmation that the Owner RLS query succeeds. Customer account mutation controls remain **Pending**.
- Owner All-in-One overall status: **In Progress**. Global Order controls, global Product controls, Platform Settings and reports remain **Pending**.


## Owner All-in-One Control — Global Order Console (2026-11-01)

- Added an Owner-only **Global Order Console** linked from the Command Center and searchable from All-in-One Control.
- Reads the latest 200 order rows visible through the existing Owner RLS policy; displays order number, business name, customer display name, status, total, payment method/status and creation time.
- Search filters the already-loaded rows locally (no database request on every keystroke).
- Privacy scope: does not display shipping addresses, order notes, phone numbers or full customer profile records.
- **Read-only**: no order status changes, refunds, cancellations or fulfilment mutations were added. These remain pending until a dedicated server-side Owner RPC with transition validation and audit logging is implemented.
- Order console source commits: `0d40fa0057534617aac75a20ae6abca1da88d3af`, `45b2ee4c5922ed70caf4359dab6a334202134e9a`.
- Customer directory and Order Console are **In Progress** pending final static validation, deployment and authenticated Owner query confirmation. No customer/order data was modified.
- Global product management, platform settings, reports, customer account mutations and order status mutations remain **Pending**.


## Owner All-in-One Control — Global Product & Stock Console (2026-11-01)

- Added a searchable Owner-only global product overview linked from the Command Center and All-in-One Control.
- Reads up to 200 newest product records through existing database access rules and displays product name, business name, stock quantity, availability and listed/sale price.
- Search filters cached results locally; refresh is explicit.
- Read-only: no product edits, deletion, stock adjustments or bulk actions are exposed. Those remain pending until server-side authorization, validation and audit behavior are confirmed.
- Does not display product images or descriptions in the global admin overview.
- Source commit: `b73b1c954cd16271e8d0fb3ab01f4d95d9d5decf`.
- Customer directory, order console and product console remain **In Progress** pending final validation/deployment and authenticated Owner query verification. No database records or schema were modified.
- Order status mutation, customer account mutation, product mutation/bulk inventory controls, platform settings and analytics remain **Pending**.


## Super High Security Shield — permanent project requirement (2026-11-01)

- Added `SECURITY_ARCHITECTURE.md` as the mandatory security specification for every Smart Business Pro module.
- Requirements include zero-trust server-side authorization, Super Admin MFA/step-up protection, Supabase RLS and tenant isolation, secret/key protection, abuse/rate limiting, input and browser attack protections, payment webhook signature/idempotency checks, audit alerts, encrypted backups and recovery.
- Added a security verification gate covering role-based access, cross-shop IDOR/BOLA, auth/session security, secret scanning, injection/XSS/CSRF, file uploads, payment replay/concurrency, backup restore and Supabase Security Advisor.
- This commit records the architecture and acceptance criteria only. It does **not** mean these controls have all been implemented or tested. The Security & Protection Module remains **In Progress**; each control must be implemented and verified before being marked Completed.
- Existing `index.html`, database schema, and business/customer records were not changed by this documentation update.


## Owner-approved 10-feature Security Shield checklist (2026-11-01)

All ten are mandatory. No feature may be omitted. Each stays **In Progress** until implementation and evidence-backed verification are complete.

| # | Security feature | Status | Required evidence before Completed |
|---|---|---|---|
| 1 | Zero-Trust Security | **In Progress** | SQL role tests cover two-tenant shops/products/orders/payments/Storage and seven additional business-module tables; owner A/B each saw only their own module rows, unrelated customer saw zero. Complete remaining HTTP/PostgREST tests and remaining RPCs. |
| 2 | Super Admin Lock | **Pending** | MFA, step-up re-authentication, server-side Owner role checks and session revocation tests. |
| 3 | Database Fortress | **In Progress** | 41/41 public tables have RLS and policies. Two-tenant SQL isolation now also passes across Electronics, Hotel, Office and Restaurant operational tables; anonymous catalog reads are column-allowlisted; shopkeeper grants are least-privilege; private limiter tables are deny-all. Complete remaining table/API matrix and HTTP/PostgREST tests. |
| 4 | Anti-Brute-Force | **Pending** | Verified rate limits, progressive delays/lockout, abuse detection and recovery tests. |
| 5 | Secret Vault | **In Progress** | Secret scanning of current files and Git history; confirm secrets server-side only; rotate any exposed credentials. |
| 6 | Attack Protection | **In Progress** | Server-side validation and negative tests for XSS, SQL injection, CSRF, IDOR/BOLA, unsafe uploads and redirects. |
| 7 | Real-Time Alerts | **In Progress** | Verified alert generation, delivery, access controls and sensitive-event coverage. |
| 8 | Backup & Recovery | **In Progress** | Encrypted backup configuration, retention/access review and successful restore drill. |
| 9 | Audit Trail | **In Progress** | Verify coverage, integrity, access restrictions, retention and safe log contents. |
| 10 | Payment Shield | **In Progress** | Test invalid signatures, amount/currency/order mismatch, duplicates, replay and concurrent webhook delivery. |

**Important:** The checklist and architecture requirements are recorded in `SECURITY_ARCHITECTURE.md`. This is documentation, not proof that all ten controls are implemented. Overall Security Shield remains **In Progress**. No claim of 100% hack-proof protection is permitted.


## Next 5 Security Shield Features — implementation audit started (2026-11-01)

The next five owner-approved features have moved from **Pending** to **In Progress** because their implementation/configuration audit has started. This is not a claim that the controls are already active or complete.

| # | Feature | Status | Current evidence / next required work |
|---|---|---|---|
| 2 | Super Admin Lock | **In Progress** | MFA/step-up requirements reviewed. Still verify Owner MFA enrollment/enforcement, AAL2 checks on sensitive server-side actions, re-authentication, and session revocation. No Auth setting or Owner access rule was changed. |
| 4 | Anti-Brute-Force | **In Progress** | Inspected active Razorpay Edge Function entrypoints; no app-level rate-limit implementation was evident in the inspected handlers. Verify Supabase Auth rate-limit settings and implement/test per-account/IP limits, progressive delays, abuse detection and safe recovery. |
| 6 | Attack Protection | **In Progress** | Reviewed the three active Razorpay Edge Functions. They validate JSON shape and payment identifiers, and the webhook verifies the raw-body HMAC-SHA256 signature. Follow-up: restrict wildcard CORS to approved origins where browser calls are needed, enforce request-size limits, audit all other inputs/outputs, CSP/CSRF applicability, upload rules, redirects and negative XSS/SQLi/IDOR tests. |
| 7 | Real-Time Alerts | **In Progress** | Alert requirements mapped to suspicious sign-ins, repeated failures, privilege changes, payment anomalies and sensitive Owner actions. No end-to-end alert delivery has been verified yet; implement destinations, access control, deduplication and delivery tests. |
| 8 | Backup & Recovery | **In Progress** | Backup/restore evidence has not yet been retrieved. Verify project backup availability, encryption, retention, access restrictions and recovery objectives; perform and record a restore drill before completion. |

### Current read-only evidence (2026-11-01)
- Supabase Security Advisor currently reports one warning: **Leaked Password Protection Disabled**. Remediation: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Supabase reports three active Razorpay Edge Functions: checkout and payment verification have JWT verification enabled; the webhook has JWT verification disabled and performs raw-body HMAC-SHA256 signature verification in its handler.
- The inspected checkout and verification handlers authenticate the user and validate payment identifiers/amount/status with Razorpay checks. Their CORS configuration currently allows wildcard origin; this should be narrowed to the actual approved browser origins after confirming all legitimate callers.
- The inspected function code did not show an application-level rate limiter, security-alert delivery pipeline, or backup/restore workflow. Absence in these three files is not proof that no platform-level controls exist; platform settings and other project components still need inspection.
- No production database records, schema, Auth settings, Edge Function deployments, secrets, or existing HTML pages were changed during this audit.

### Safety gate
- Keep all five features **In Progress** until their actual controls are configured/implemented and relevant automated/API tests pass.
- Do not deploy untested rate limiting, MFA gates, CORS restrictions, alert pipelines or recovery changes that could lock out legitimate users or disrupt payments.
- Preserve index.html, existing business flows and database records unless a reviewed change is necessary.


### Follow-up read-only audit (2026-11-01)
- Supabase project state is **ACTIVE_HEALTHY**; organization tier is **Free**. Backup/PITR availability, retention and restore capability are still not confirmed from this metadata, so Backup & Recovery remains In Progress.
- Targeted database catalog query confirms RLS is enabled on `profiles`, `shops`, `audit_logs` and `payments`. Current policy counts: profiles 2, shops 5, audit_logs 2, payments 1. Policy names/counts are not proof of policy correctness; predicate and role coverage still require review and negative authorization tests.
- `audit_logs` has admin SELECT and INSERT policies, but end-to-end audit event coverage, tamper resistance, retention and Owner-only UI visibility have not been verified. Audit events are not yet declared Completed.
- The current project metadata and available read-only APIs did not expose a verified MFA enforcement configuration or backup/restore drill. No MFA settings, Auth rate limits, database schema/data, secrets, Edge Functions, or frontend files were changed.
- Security Advisor still reports **Leaked Password Protection Disabled**. Enable it in Supabase Auth password security settings after reviewing the impact on existing password users.


## Automated hardening and database verification — 2026-11-02

- Extended `scripts/validate-static.mjs` to check local href/src targets, ensure target=`_blank` anchors include `rel=noopener`, scan public HTML/JS for common private-key and payment-secret patterns, and retain JavaScript syntax, duplicate-ID and 11-category checks.
- The expanded validator commit is `4bdedaa0c065102fc55555c7d9b12525dd08033b`. Its GitHub Actions result must be checked before this validator enhancement is marked Completed; the previous attempt on `49a577aa1ad8fba4df161002a86697832cfd5c11` failed because of a validator regex-escaping defect, which was corrected in the follow-up commit.
- Supabase read-only catalog verification: 41 public tables; 0 with RLS disabled; 0 RLS-enabled tables without any policy; 0 UPDATE policies missing WITH CHECK. Seven public/anon mutation policies were reviewed structurally. Customer-request INSERT policies constrain status, ownership and active shop state; direct order INSERT has a false WITH CHECK predicate. This is not a substitute for negative API tests with anon, Customer, Shopkeeper and Super Admin sessions.
- The `shops` table has four non-internal guard triggers, including protected activation-field changes, immutable business type for non-admins, and subscription-expiry tamper protection. No production database changes were made.
- Supabase project remains ACTIVE_HEALTHY on the Free tier. Official Supabase documentation states leaked-password protection is available on Pro and above; therefore the existing Security Advisor warning is plan-gated on the current tier, not a website-code defect. Keep this item open until the plan supports it and the setting is verified: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Existing customer storefront `index.html` remains unchanged (blob SHA `854f4646215be9f0a5aaacc72ad4b7b56ac58f3e`). No Auth settings, schema, RLS policies, customer/shop records, payment records, Edge Function deployments or secrets were changed.


## Static hardening verification result — 2026-11-02

**Static validation passed.**

- Corrected the validator to ignore runtime-generated template URLs while still checking static local paths.
- GitHub Actions static validation passed on commit `ab83f827e611403b6d786fddef5d0a90669a9a31`, run `41377126260`: **283 checks across 14 HTML pages, 1 public script and all 11 business categories**.
- Checks include inline JavaScript syntax, duplicate IDs, local href/src targets, `target="_blank"` rel=noopener, common secret/key patterns in public HTML/JS, and category presence across registration, workspace, Owner controls and portal.
- Latest Pages deployment and GitHub Pages build for this commit were still queued/pending at the time of this update (runs `41377126262` and `41377126180`). Keep deployment status pending until both complete successfully.


## Security audit expansion — 2026-11-02 (read-only; remediation pending)

- Supabase function catalog review found 71 functions in public/private schemas, 43 marked SECURITY DEFINER. Of these, 32 have a function-level search_path including public and 17 are executable by anon according to PostgreSQL privilege checks. Many are private helper/trigger functions; this is not by itself proof of remote exposure. However, anon and authenticated currently have USAGE on the private schema, so the API-exposed schema configuration and each callable function's intended audience must be verified. **Do not revoke schema/function privileges blindly** because existing customer booking/request flows may depend on selected anonymous entrypoints. First enumerate API-exposed schemas and all callers, then restrict private schema access to the minimum required and test every legitimate flow.
- The SECURITY DEFINER inventory includes owner control RPCs that contain explicit private.is_super_admin() checks, payment activation that allows only trusted service-role or active Super Admin, and customer request entrypoints with input validation. Continue full function-by-function review for caller authorization, fixed search_path, fully qualified object references and safe grants.
- Public schema view catalog returned no views in the targeted query. PostgreSQL row_security is ON. API-exposed schema list was not available from pg_settings; verify it in Supabase API settings before treating private as non-exposed.
- Backup docs reviewed against current Free tier: Supabase's official guide says daily automatic backups are for Pro/Team/Enterprise, and recommends Free projects regularly export with Supabase CLI db dump and keep off-site copies. Storage objects are not included in database backups. Therefore Backup & Recovery is currently **Blocked for managed daily backups on Free tier**, but a manual database + Storage export/restore plan can be implemented and tested. Official docs: https://supabase.com/docs/guides/platform/backups
- No production schema, privileges, Auth settings, functions, secrets, or user/business/payment data were changed in this read-only audit.


## Backup implementation constraint — 2026-11-02

- Managed daily Supabase backups are not included on this project's Free tier. A manual recovery plan is required: export database with Supabase CLI db dump, export Storage objects separately, encrypt and store copies off-site, record backup date/checksum, and restore into a separate safe project before claiming Backup & Recovery Completed.
- Do not use the production restore action as a test; it can cause downtime and roll back current records. A restore drill must target a separate non-production project.
- Current status: managed daily backups are Blocked by plan; manual export/restore implementation is In Progress.


## Applied security remediation — 2026-11-02

**Database Fortress sub-control implemented and verified (this does not complete the full Database Fortress feature):**
- Added migration `20261102100000_revoke_client_execute_on_private_trigger_functions.sql` and applied it successfully to Supabase.
- Revoked direct `EXECUTE` from `PUBLIC`, `anon`, and `authenticated` for every attached trigger-returning function in the `private` schema. PostgreSQL triggers continue to invoke their trigger functions; these functions are not intended as client RPC endpoints.
- Post-migration read-only verification: **23 attached private trigger functions remain registered; 0 are directly executable by anon; 0 are directly executable by authenticated.**
- Supabase Security Advisor after migration reports only the existing leaked-password-protection warning in its returned security lint list. This is plan-gated on the current Free tier; it is not silently marked resolved.
- No customer/business/payment records were changed. Existing `index.html` was not edited.

**Remaining Database Fortress gates:** review every RLS predicate and storage policy; verify API-exposed schema settings; review all remaining SECURITY DEFINER functions and intended anonymous RPCs; perform negative role/tenant-isolation API tests. Do not mark feature 3 Completed yet.


## Post-remediation privilege clarification — 2026-11-02

- The earlier count of 17 anon-executable SECURITY DEFINER functions included private trigger functions that were subsequently hardened. After the applied migration, the current catalog shows **32 SECURITY DEFINER functions in private (6 anon-executable, 21 authenticated-executable) and 11 in public (0 anon-executable, 0 authenticated-executable)**.
- The 6 remaining anon-executable private functions are the named public-intake/availability helpers: `is_active_digital_service_shop`, `is_active_electronics_service_shop`, `is_active_hotel_booking_shop`, `is_active_restaurant_booking_shop`, `is_public_shop_active`, and `submit_digital_service_application`. They need an explicit API-exposed-schema and input/output review; do not revoke them blindly because public storefront/booking/request flows may rely on them.
- All 23 attached private trigger functions now have no direct EXECUTE grant for anon or authenticated. The trigger definitions remain attached.


## Security audit continuation — 2026-11-02 (read-only; no production changes)

- Confirmed the three GitHub checks for the latest security-doc commit completed successfully: static validation, static website deployment, and GitHub Pages build/deploy. These validate build/source integrity only; they do not prove runtime authorization or complete the Security Shield.
- Re-read live RLS policies in both `public` and `storage`. The three Storage policies restrict product-image upload/update/delete to the authenticated owner of the active shop, with a UUID shop-folder prefix. The `product-images` bucket has a 5 MB limit and allows JPEG, PNG and WebP. The `shop-logos` bucket is public and currently has no explicit file-size or MIME allowlist in bucket metadata; inspect its actual object write policies and client upload validation before treating upload security as complete.
- Found a material configuration dependency: PostgreSQL currently reports `USAGE` on schema `private` for both `anon` and `authenticated`; neither role has `CREATE`. This database grant alone does not establish whether `private` is exposed through the Supabase Data API. The API exposed-schema allowlist must be checked in Supabase API settings. Do not revoke `USAGE` until that setting and all legitimate RPC callers are confirmed.
- Reviewed all six remaining anon-executable SECURITY DEFINER functions in `private`. Four category availability helpers and `is_public_shop_active` return only a boolean and use fixed/empty search paths with schema-qualified relations. `submit_digital_service_application` validates shop status, service/name/phone lengths and formats, notes limits, and inserts through a constrained RPC; it uses an empty search path and schema-qualified objects. These source checks are positive but do not replace API exposure verification, abuse/rate-limit tests, and negative API tests.
- The RLS policy inventory includes deliberate public/anon mutation entrypoints only for customer reservation, hotel booking-request and electronics repair-job intake; their predicates constrain initial status, customer identity (including null for anon), shop category/active subscription, and client-controlled privileged fields. The `orders` direct INSERT policy explicitly has `WITH CHECK (false)`. Profile and delivery-address policies are scoped to the current auth UID or private Super Admin check. These predicates still need real JWT/API tests for signed-out and cross-tenant cases.
- Storage inventory: `shop-logos` and `product-images` are public-read buckets. Product-image uploads are constrained to authenticated active shop owners and a 5 MB image allowlist. Public read is intentional for storefront display; verify no private customer documents are placed in either bucket.
- Current Supabase Security Advisor continues to report one warning: leaked-password protection disabled. This is plan-gated on the current Free tier according to Supabase documentation; do not claim it is enabled or resolved.
- No database grants, RLS policies, bucket settings, Edge Functions, Auth settings, secrets, payment records, or business data were changed during this audit. `index.html` remains untouched.
- **Next Database Fortress gate:** confirm the Data API exposed-schema allowlist, review all grants on exposed schemas and bucket policies (including `shop-logos`), then run authenticated/anon API negative tests using dedicated test identities and non-production fixtures. Do not mark Database Fortress complete before those checks pass.

**Status precedence:** This security-first execution lock supersedes older sections in this file that describe the Business Category Module or other feature modules as the current active implementation. Until the 10 Security Shield features pass their evidence gates, only security work and safe maintenance/regression fixes are authorized.


## Storage security follow-up — 2026-11-02

- Re-queried live `storage.objects` policies: exactly three policies exist, all scoped to authenticated shop owners and the `product-images` bucket. INSERT, UPDATE (USING + WITH CHECK), and DELETE require a UUID shop folder whose shop is owned by auth.uid(), active, enabled, and not expired.
- Confirmed `shop-logos` currently has **no matching Storage object policy**. Its bucket is public-read, with no configured max file size or MIME allowlist. The inspected shopkeeper frontend uploads product images only to `product-images`; no `shop-logos` upload call was found in that page. Do not add a permissive write policy. Before changing bucket limits or adding upload permissions, trace every Owner/Edge Function/admin upload caller and any existing logo objects.
- Confirmed `product-images` is public-read with 5 MiB limit and JPEG/PNG/WebP allowlist. Keep customer documents and private records out of both public buckets.
- The PostgreSQL runtime did not expose PostgREST `pgrst.db_schemas` via `current_setting` (NULL); this is not evidence that `private` is or is not exposed. Supabase API settings must be checked in the Dashboard; do not infer the exposed schema list from SQL grants.
- Supabase Security Advisor still reports leaked-password protection disabled (plan-gated on current Free tier).
- No production changes made in this follow-up. No bucket configuration, Storage policies, API settings, customer files, payment data, or application pages were modified.
- **Next:** inspect Owner/Edge Function logo-upload call paths and existing bucket objects; then confirm API exposed schemas through project settings and prepare dedicated test identities for Storage and RLS negative API tests.


## Security Shield continuation update — 2026-11-02 (evidence-based)

Security-first execution lock remains in force. Do not begin business-category or feature-module work until all 10 Security Shield features pass their evidence gates. No feature is promoted to fully Completed by this update.

### Storage surface inventory — read-only follow-up
- Live Storage inventory: `product-images` is public-read, 5 MiB limit, JPEG/PNG/WebP allowlist, with 1 existing object (JPEG, 47,438 bytes) under a UUID shop folder.
- `shop-logos` is public-read, has no configured size/MIME restriction, and currently has 0 objects.
- Repository inspection: `shopkeeper.html` uploads/deletes only in `product-images`; `owner.html` and `digital-service-request.html` contain no Storage upload references. GitHub code search for `shop-logos` returned no matches.
- No bucket settings or Storage policies changed. Do not add a `shop-logos` write policy or change bucket configuration until all upload paths and any future use are explicitly designed and tested.
- Existing `product-images` object metadata is present; no object content was downloaded or exposed.

### Owner / MFA / audit UI inspection
- `owner.html` uses email/password sign-in and reads the latest 100 `audit_logs` records for display.
- No MFA enrollment, AAL2 assurance check, or step-up/re-authentication flow was found in the inspected Owner page.
- This is evidence that Super Admin Lock remains incomplete; do not enable MFA enforcement until enrollment, recovery, and server-side sensitive-action checks are implemented and tested.

### Razorpay source reinspection
- Checkout and payment-verification Edge Functions require a user session (`verify_jwt=true` at deployment and `withSupabase({auth:"user"})` in source).
- Webhook is intentionally deployed with JWT verification disabled and validates the raw-body HMAC-SHA256 signature before processing.
- Checkout and verification still emit wildcard CORS (`Access-Control-Allow-Origin: *`). Do not narrow until legitimate deployed origins and browser regression tests are established.
- Source inspection is not an end-to-end replay/concurrency/idempotency test. Payment Shield remains incomplete.

### Exposed-schema configuration
- The project SQL runtime does not expose the PostgREST `pgrst.db_schemas` setting (`current_setting` returned NULL in the prior audit), and project metadata tools do not expose the Data API allowlist. Dashboard confirmation remains outstanding: Integrations → Data API → Exposed schemas.
- Do not infer that the `private` schema is or is not exposed; do not revoke schema USAGE until this is confirmed and callers are mapped.

### Current gate
- This update is inventory and source review only; it changes no production data, bucket policy, payment flow, auth policy, or `index.html`.
- Security Shield full-feature count remains **0/10 fully verified**. The previously applied private trigger-function EXECUTE revocation remains a completed sub-control only.
- Next: confirm exposed schemas in Dashboard; build isolated authenticated test identities and negative cross-tenant API tests; then implement only the smallest evidence-backed remediation with migration + automated verification.


### Read-only RLS role simulation — 2026-11-02
Executed inside explicit transactions using `SET LOCAL ROLE` and synthetic JWT subject claims; each transaction was rolled back. No rows were inserted, updated, or deleted.
- Existing shop-owner identity: `authenticated` role + matching owner subject saw exactly 1 owned shop and 1 subscription row; saw 0 audit-log rows.
- Synthetic non-owner authenticated subject: saw 0 shops, 0 subscriptions, 0 audit-log rows, and 0 digital-service applications.
- Anonymous role: saw 1 shop, 1 product, and 48 categories through the intended public-read paths. A separate anonymous attempt to read `shop_subscriptions` was denied by table privileges (Postgres 42501); no grant was added.
- The live dataset currently contains only one shop owner / one shop. Therefore this is a useful positive-owner and negative-non-owner check, but it is **not** a real two-tenant cross-shop IDOR test. A second isolated shop-owner test identity and second tenant are still required before Database Fortress can pass.
- These are SQL role simulations, not authenticated HTTP/PostgREST requests. API-level negative tests remain outstanding.


### Additional callable-function and RLS predicate tests — 2026-11-02
- Re-audited function ACLs and definitions. No SECURITY DEFINER functions were found in `public`; public RPC wrappers are SECURITY INVOKER and delegate to guarded private routines. The public `submit_digital_service_application` RPC is intentionally executable by anon/authenticated for customer intake; its private SECURITY DEFINER implementation validates active digital-service shop and validates service/name/phone/notes lengths before insert.
- Negative SQL role simulation: anon call to public digital-service intake with a non-existent shop was rejected with SQLSTATE `55000` (“not currently accepting requests”). No row was inserted.
- Negative SQL role simulation: a synthetic non-admin authenticated subject calling `public.owner_set_shop_status` for the real shop was rejected with SQLSTATE `42501` (“Only active super_admin…”). Transaction rolled back; shop status unchanged.
- These are SQL-level checks, not authenticated HTTP/PostgREST tests; no claim of full API authorization coverage.
- Targeted UPDATE-policy review found a predicate mismatch on `grocery_expenses_update`: its `USING` clause requires ownership of an active Grocery shop with unexpired subscription, while `WITH CHECK` only requires shop ownership and `created_by = auth.uid()`. No trigger exists on `grocery_expenses` to enforce immutable `shop_id`. This may allow a row to be reassigned by its creator to another shop they own (including a non-active/non-Grocery shop) during an otherwise permitted update. It does not currently establish cross-user tenant access, but is a data-integrity / tenant-boundary hardening finding.
- No production policy was modified. Remediation must preserve legitimate expense editing and be verified with an isolated two-shop owner test before applying a migration.
- Feature gates remain unchanged: Security Shield 0/10 fully verified.


### Audit Trail hardening — 2026-11-02
- Added and applied `supabase/migrations/20261102183000_restrict_direct_audit_log_writes.sql`.
- Revoked direct INSERT on `public.audit_logs` from `authenticated` and removed the obsolete `audit_admin_insert` policy. Authenticated SELECT remains; anon has no SELECT or INSERT.
- Live privilege verification: authenticated SELECT=true, INSERT=false; anon SELECT=false, INSERT=false. The remaining `audit_admin` policy is SELECT-only.
- Five app routines that write audit events are SECURITY DEFINER functions owned by `postgres`; Owner page uses SELECT only. Direct authenticated INSERT test failed as expected with SQLSTATE 42501 and created no row.
- This prevents ordinary client sessions from fabricating audit events. Event coverage, privileged-operator tamper resistance, retention and alerting remain unverified; Audit Trail is still In Progress.
- No existing audit rows or business/payment data were changed; `index.html` remains untouched.


### Post-migration CI and role-guard review — 2026-11-02
- GitHub Actions passed on commit `5e4de566de5012f826f5863c0ca020dac7f27f10`: Static project validation, static Pages deployment, and Pages build/deployment all completed successfully (runs 41388913703, 41388913725, 41388913171).
- Supabase migration history confirms `restrict_direct_audit_log_writes` is applied (version 20261102043013).
- Reviewed `private.is_super_admin()` and `private.is_shop_owner(uuid)`: both use `auth.uid()` and active `profiles` role/ownership checks; no user-editable metadata claim is used for role authorization.
- Reviewed `public.prevent_role_escalation()`: rejects new Super Admin accounts, restricts role/activation changes to existing active Super Admin, protects the last active Super Admin, and disables owned shops when a shopkeeper is disabled/demoted. Source review only; negative API test for profile role escalation remains outstanding.


### UPDATE policy predicate comparison — 2026-11-02
- Compared `USING` and `WITH CHECK` expressions for all public UPDATE policies. Eleven policies differ; ten differences add destination-row integrity constraints (for example, same-shop product/room/employee references or amount bounds).
- The remaining exception is `grocery_expenses_update`: `WITH CHECK` omits the active Grocery shop + unexpired-subscription predicate present in `USING`, and the table has no trigger protecting `shop_id`. Keep this as a specific Database Fortress remediation candidate; do not alter until an isolated test confirms intended expense-edit behavior.
- No RLS policy was changed in this review.


### Remaining private SECURITY DEFINER helper review — 2026-11-02
- A catalog scan of authenticated-executable private SECURITY DEFINER functions that do not reference `auth.uid()` identified six boolean helpers: five public-shop/category availability checks and `is_active_free_trial(uuid)`.
- The five public availability helpers return only whether a shop is currently active for a category and are intentionally used by public/customer-facing policies or intake paths. `is_active_free_trial(uuid)` also returns a boolean for an arbitrary shop ID, has authenticated EXECUTE privilege, and was not found in current RLS policy expressions or other database function bodies. Its direct application caller and Data API exposure are not yet confirmed.
- Treat `is_active_free_trial` as a potential unnecessary information-disclosure surface, not a confirmed exploitable endpoint. Keep its privilege unchanged until Data API exposed schemas and all app callers are verified; then revoke direct client EXECUTE if unused and add a negative API test.


### Grocery expense tenant-integrity remediation — applied and verified (2026-11-02)
- Added migration `supabase/migrations/20261102190000_harden_grocery_expense_update_tenant_integrity.sql`; Supabase migration history records it as applied (`20261102043649`).
- `grocery_expenses_update WITH CHECK` now repeats the same owner + active Grocery + active status + unexpired subscription requirements as `USING`, and requires `created_by = auth.uid()`.
- Added a private SECURITY INVOKER BEFORE UPDATE trigger that rejects authenticated changes to `shop_id` or `created_by`. Trigger function uses an empty search_path and direct EXECUTE is revoked from PUBLIC/anon/authenticated.
- Live verification confirms the trigger is attached, function is not SECURITY DEFINER, anon/authenticated cannot directly execute it, and policy predicates now match the intended tenant/active-shop requirements.
- Transactional negative test (rolled back): temporarily granted table privileges only inside the test transaction, created one temporary row, confirmed a normal description edit was accepted, and confirmed attempts to change `shop_id` and `created_by` were rejected with SQLSTATE 42501. The temporary row did not persist; temporary grants were rolled back.
- Important current-state finding: authenticated has no SELECT/INSERT/UPDATE/DELETE table privileges on `grocery_expenses`, so the table is not currently writable/readable by ordinary clients through table grants. No privileges were added permanently. Do not grant access until an actual feature caller is designed and tested.
- Existing expense data was preserved; `index.html` unchanged. This remediation is a verified sub-control, not completion of Database Fortress or the 10-feature Security Shield.


### Unused SECURITY DEFINER trial helper lockdown — applied and verified (2026-11-02)
- Full tracked client source scan across all HTML/JS/TS files and all three Razorpay Edge Functions found no caller for `private.is_active_free_trial(uuid)`. A database routine-body scan also found zero callers.
- The function was SECURITY DEFINER, returned a boolean for an arbitrary shop ID, and had direct EXECUTE for authenticated users. Added and applied migration `supabase/migrations/20261102200000_revoke_unused_free_trial_helper_execute.sql` to revoke EXECUTE from PUBLIC, anon and authenticated.
- Verified live function privileges: anon=false, authenticated=false, service_role=false. A direct call under `SET LOCAL ROLE authenticated` failed with SQLSTATE 42501 as intended. No function body or trial data was changed.
- This removes an unused callable surface; it does not complete Zero-Trust or Database Fortress.

### Latest CI snapshot — 2026-11-02
- Static project validation passed on commit `258b12bd75839fab7a48cff8455da3297223b988` (run 41389708281).
- Static Pages deployment and Pages build/deployment for that same commit were still in progress at the time of this update. Previous commit `b53e08a3ec738a9c28bfe8714bd64e3c513d7b34` passed all three CI workflows.


### CI verification after helper lockdown — 2026-11-02
- Static project validation passed on commit `f704914688ec73d59cb83107b52d7c12945b88f8` (run 41389754781).
- Static Pages deployment passed on the same commit (run 41389754795).
- Pages build/deployment was still in progress at the last check (run 41389754703); no success claim until it completes.


### Audit trigger compatibility correction and private-schema move — 2026-11-02
- Follow-up audit found `public.audit_order_status()` was a SECURITY DEFINER trigger function (the earlier note that no SECURITY DEFINER functions existed in `public` was incomplete). It was attached to `orders` and writes both `audit_logs` and `order_status_history`.
- To keep trusted trigger writes working after revoking direct client INSERT on `audit_logs`, moved the trigger implementation to `private.audit_order_status()` with `SECURITY DEFINER` and empty `search_path`; recreated `trg_audit_order` to call the private function; revoked direct EXECUTE from PUBLIC/anon/authenticated; removed the old public function.
- Verified: trigger now points to `private.audit_order_status()`, old public function is absent, anon/authenticated cannot directly execute the new trigger function, and postgres can execute it.
- Transactional trigger test passed: created a temporary order, changed pending → processing, observed exactly 1 audit row and 1 order_status_history row for that order, then rolled back the entire transaction. No order or audit data persisted from the test.
- The earlier public SECURITY DEFINER catalog scan now shows only legacy trigger/helper routines with direct anon/authenticated EXECUTE revoked; no direct public RPC access was found in the inspected ACLs. Their attached triggers/callers remain under review; do not delete or move them without dependency mapping.
- Existing production audit rows remain unchanged. This confirms the Audit Trail write path still functions after client INSERT revocation; event coverage and tamper/retention requirements remain open.


### Payment Audit Trail coverage — implemented and transaction-tested (2026-11-02)
- Added and applied `supabase/migrations/20261102220000_audit_payment_state_changes.sql`.
- A private SECURITY DEFINER trigger now records payment creation and changes to security-relevant payment fields (owner/order/subscription linkage, amount, currency, status, gateway, gateway IDs, verified flag). It deliberately excludes raw `gateway_payload` from audit JSON.
- Trigger function has empty `search_path`; direct EXECUTE is revoked from PUBLIC/anon/authenticated. The `audit_logs` table remains non-writable directly by ordinary authenticated clients.
- Transactional test passed: changed the existing pending payment to `success`/verified inside a transaction, observed one matching `payment` audit event, then rolled back. Follow-up read confirmed the real payment remains `pending`/unverified and no payment audit row persisted from the test.
- This improves payment event traceability but does not prove full payment security (webhook signature/replay/idempotency tests remain pending) or complete Audit Trail coverage for every privileged mutation.


### Super Admin Lock — server-side AAL2 gate and Owner MFA setup (2026-11-02)
- Updated `owner.html` with a TOTP authenticator enrollment flow, QR/manual setup key display, 6-digit challenge verification, and a fail-closed MFA gate before rendering the Owner dashboard. Incomplete enrollment can be restarted; the UI advises keeping a second trusted authenticator/recovery path.
- Added and applied `supabase/migrations/20261102230000_require_aal2_for_super_admin_authorization.sql`. `private.is_super_admin()` now requires both an active `super_admin` profile and JWT `aal='aal2'`. This gates the existing Owner RPCs and all RLS/trigger paths that rely on the central helper; service-role payment webhook logic remains on its separate trusted service-role branch.
- Synthetic JWT SQL tests passed for the initial AAL2 gate: Super Admin + AAL1 → denied; Super Admin + AAL2 → allowed at that stage; non-admin + AAL2 → denied; shopkeeper still passes their own-shop check at AAL1. A subsequent hardening migration below adds a verified-TOTP-factor check, so AAL2 alone no longer grants Owner access when no verified factor exists. All tests were read-only/rolled back.
- Live Auth factor inventory currently shows **no MFA factors enrolled** for the active Super Admin account. The Owner dashboard is therefore intentionally gated until the account holder signs in to `owner.html`, enrolls a TOTP authenticator, and verifies a code. No factor was enrolled or secret generated automatically.
- Recovery dependency: keep authenticator access on a second trusted device or store the setup key securely. If all factors are lost, the project administrator must recover the factor through Supabase Auth administration. Do not claim Super Admin Lock fully Completed until the real account enrollment, fresh-login AAL2 check, and sensitive-operation negative API tests pass.
- CI passed on commit `703123399f064f3a376ddac74ad251438e327e1f`: Static project validation, static Pages deployment, and Pages build/deployment all succeeded (runs 41390857065, 41390857047, 41390856866).


### Client-side XSS sink and SQL dynamic-query review — 2026-11-02
- Static scan covered 19 tracked HTML/JS/TS files (including the three Razorpay Edge Function sources). Found 16 `innerHTML` sinks; no `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval`, `new Function`, or dynamic `location.assign/replace` sinks.
- Reviewed the live storefront `index.html` sinks without modifying the file: database-backed product/category text is passed through `escapeHTML`; product IDs are UUID-typed database fields; quantity/price values are numeric; fallback markup is constant. `catalogue.html` and `showcase.html` render local static catalogue arrays. Owner panel uses DOM text nodes/textContent for audit event data.
- Database function source scan found only `rls_auto_enable` using dynamic SQL; it uses `format('%I.%I', schema_name, table_name)` with catalog-derived identifiers, rather than concatenating user input. No application-provided dynamic SQL was found in the reviewed public/private functions.
- This is a static sink/source review, not a full browser payload/XSS test or SQL injection penetration test. Attack Protection remains In Progress. `index.html` was not changed.
- Latest commit `c60c844d2b920b967265cd930a4b9a17b3c2c380` passed Static project validation, static Pages deployment, and Pages build/deployment (runs 41391032908, 41391032899, 41391032805).


### Isolated two-tenant RLS tests — passed with rollback (2026-11-02)
- Built a temporary second Auth identity, shopkeeper profile, inactive Grocery shop and product inside a single explicit transaction. Used synthetic JWT subjects for the existing shop owner and the temporary second owner, both at AAL1. No real user credentials were created.
- `shops` isolation: tenant 1 saw exactly its own shop and could not see or own tenant 2's shop; tenant 2 saw exactly its own test shop and could not see tenant 1's shop.
- `products` isolation: tenant 1 could not see tenant 2's test product; tenant 2 could see its own test product.
- All test operations were rolled back. Follow-up checks confirmed the temporary Auth user, shop and product all have 0 persisted rows. No production user, shop, product or payment data changed.
- This is stronger than the earlier one-tenant simulation and validates core row isolation for `shops` and `products` under two synthetic authenticated identities. It is still SQL role simulation, not full HTTP/PostgREST API testing, and does not cover every table or Storage policy. Database Fortress remains In Progress.


### Two-tenant Storage upload RLS tests — passed with rollback (2026-11-02)
- Created a temporary authenticated shopkeeper, active test shop and Storage object attempts entirely inside a transaction. The shop was activated only through a synthetic service-role claim in the test transaction; no live shop status was changed.
- Existing shop owner attempting to INSERT a `product-images` object into the other tenant's UUID shop folder was rejected by Storage RLS (SQLSTATE 42501).
- The temporary shop owner successfully INSERTed a `product-images` object into their own active shop folder, confirming the positive owner path.
- Transaction rolled back. Follow-up checks show 0 persisted test Auth users, 0 test shops and 0 test Storage objects. Existing bucket settings, policies and files were not changed.
- This verifies cross-tenant Storage write isolation for `product-images` at SQL role level. It does not replace full Storage HTTP API tests or cover `shop-logos` (which intentionally has no write policy).


### Customer/order/payment row isolation and profile privilege tests — passed with rollback (2026-11-02)
- Order visibility test using a temporary Auth customer and order: unrelated customer saw 0 rows; order-owning customer saw 1; owning shopkeeper saw 1. Transaction rolled back.
- Payment visibility test using a temporary pending payment attached to the temporary order: unrelated customer saw 0; payment-owning customer saw 1; owning shopkeeper saw 1; Super Admin at AAL1 saw 0; Super Admin at AAL2 saw 1. Payment insert also exercised the protected payment trigger and new audit trigger; all changes were rolled back.
- Follow-up checks confirmed 0 persisted temporary Auth users, orders, payments or audit rows.
- Profile privilege test: authenticated customer could update their own `full_name`, but direct `role` escalation was blocked by missing column UPDATE privilege (SQLSTATE 42501). Test transaction rolled back.
- These SQL role simulations now cover two-tenant `shops`/`products`, customer-vs-shopkeeper `orders`, payment owner/shopkeeper/Super Admin AAL2 visibility, profile role-field protection, and Storage upload isolation. Authenticated HTTP/PostgREST negative tests and full table-by-table coverage are still outstanding; Zero-Trust and Database Fortress remain In Progress.


### Public digital-service intake anti-abuse limiter — applied and tested (2026-11-02)
- Added and applied `supabase/migrations/20261102240000_rate_limit_public_digital_service_intake.sql`.
- The public digital-service intake RPC now applies atomic rolling 60-minute limits: max 5 submissions per normalized phone number per shop, and max 120 submissions per digital-service shop. Exceeding either limit raises PostgREST `PT429` (HTTP 429).
- Phone/shop identifiers are HMACed with a random 32-byte key stored in a private, RLS-enabled table. Rate-limit counters are in a private RLS-enabled table; PUBLIC/anon/authenticated/service_role have no table access and cannot directly execute the limiter. Old counters are cleaned after 7 days.
- Positive/negative transactional tests passed: first 5 same-phone requests succeeded and the 6th was blocked; 120 different-phone requests succeeded and the 121st for the shop was blocked. Each test was rolled back; follow-up checks confirm 0 persisted test users, shops, applications or rate-limit rows.
- This is an application-level abuse control for the public intake RPC, not IP-level rate limiting. Supabase Auth sign-in rate limits and dashboard CAPTCHA/bot settings still require project Dashboard confirmation. No real applicant or shop data was changed.


### Payment Shield database negative/idempotency tests — passed with rollback (2026-11-02)
- Built temporary shop/subscription/payment fixtures inside transactions using the trusted service-role claim; no real Razorpay transaction or customer payment was created.
- Idempotency test: first `verify_payment_and_activate` call marked payment verified, activated the pending subscription and shop, and wrote payment audit events. A second call returned success without repeating activation. Exactly 3 payment audit events were observed for the insert, captured-state update and verified-state update. Entire transaction was rolled back.
- Negative test 1: captured payment payload without either `signature_verified` or `webhook_signature_verified` was rejected (SQLSTATE 55000); payment remained unverified and shop inactive.
- Negative test 2: verified-capture flags with an amount different from the active plan price were rejected (SQLSTATE 22023); payment remained unverified and shop inactive.
- Follow-up checks confirmed 0 persisted test shops, subscriptions, payments or audit rows.
- These prove database-side verification guards and idempotent activation under a trusted-process simulation. They do not test live Razorpay HMAC generation, invalid HTTP webhook signatures, duplicate webhook HTTP delivery, or concurrent webhook requests; Payment Shield remains In Progress.


### Internal digital-service helper privilege reduction — applied and verified (2026-11-02)
- Found `private.is_active_digital_service_shop(uuid)` was `SECURITY DEFINER`, callable by `anon` and `authenticated`, but had no RLS-policy callers and no browser-side caller. Its only required use is nested inside `private.submit_digital_service_application(...)`, itself a controlled `SECURITY DEFINER` intake routine.
- Added migration `supabase/migrations/20261102250000_revoke_unused_digital_service_helper_execute.sql` and applied it successfully. Direct EXECUTE is now false for `anon` and `authenticated`, remains available to the function owner, and the intended public `public.submit_digital_service_application(...)` RPC remains executable by anonymous and authenticated callers.
- Verified no temporary test user/shop/application rows persisted after aborted test setup attempts. No real application or shop data changed.
- The rate-limit helper's two private tables have RLS enabled, zero policies, and no SELECT/INSERT/UPDATE/DELETE table privileges for `anon` or `authenticated`; Security Advisor reports the no-policy finding as INFO, consistent with intentionally deny-all private storage. The `private` schema currently has USAGE granted to anon/authenticated; its exact Data API exposed-schema configuration is still not readable from project metadata, so dashboard confirmation remains required before deciding whether any broader private-schema exposure changes are necessary.
- Latest CI for commit `97b5da24a96d56e6fbdf844b2f74e7edff3994f9` passed: static validation (41392724917), static Pages deploy (41392724822), and Pages build/deployment (41392724305).
- Security Advisor currently reports two INFO findings for the deny-all private rate-limit tables and one WARN for leaked-password protection being disabled. The latter is plan-gated on this Free project; see https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.


### Audit Trail ACL and event-coverage inventory — 2026-11-02
- `public.audit_logs` privileges verified: `anon` has no SELECT/INSERT/UPDATE/DELETE; `authenticated` has SELECT only and no INSERT/UPDATE/DELETE. Its sole SELECT policy calls `private.is_super_admin()`, which now requires active Super Admin + AAL2.
- Database audit triggers currently cover order status changes and payment security-state changes. Owner approval, Owner shop status, Owner shopkeeper status, and subscription checkout routines also contain explicit audit inserts.
- Event-coverage gap remains: no audit trigger was found on `profiles`, `shops`, `shop_subscriptions`, `digital_service_applications`, `restaurant_reservations`, `hotel_booking_requests`, `electronics_service_jobs`, `office_attendance`, or `grocery_expenses`. Some mutations may be covered by explicit RPC audit inserts, but this has not yet been exhaustively proven for every path. Do not mark Audit Trail Completed until the full mutation-path inventory and required event matrix are verified.
- Trigger inventory and ACL checks were read-only. No audit records, user data, or business data were changed.


### Corrected digital-service anti-abuse control to a true sliding window — applied and tested (2026-11-02)
- Review found the earlier counter implementation was a fixed window despite being described as rolling. Replaced it with `private.digital_service_intake_rate_limit_events`, storing only HMACed phone/shop identifiers and event timestamps; no raw applicant phone is copied into the rate-limit store.
- Added transaction-scoped advisory locks in a deterministic phone-then-shop order. The function now counts successful submissions in the actual preceding 60 minutes, then inserts two scoped events atomically. Limits remain 5 per phone per shop and 120 per shop per 60 minutes. This prevents the fixed-window boundary burst and serializes concurrent attempts on the same phone/shop key.
- Applied migration `supabase/migrations/20261102260000_use_sliding_window_digital_service_intake_limits.sql`. Verified the limiter function is owned by postgres, callable only by its owner, and the intended `private.submit_digital_service_application` wrapper remains callable by anon/authenticated. Event table RLS is enabled and anon/authenticated have no table privileges.
- Transaction tests passed: 5 same-phone events allowed and sixth blocked; 120 shop events allowed and 121st blocked; five events timestamped 59 minutes ago blocked the next request; five events timestamped 61 minutes ago did not block it. All test transactions rolled back; follow-up check confirmed 0 persisted test events.
- Supabase Security Advisor reports the private event/key/counter tables as INFO RLS-enabled/no-policy findings (intentional deny-all; no anon/auth table privileges) and one WARN for Free-tier leaked-password protection disabled. No production applicant, shop, or payment data was changed.
- CI passed for migration commit `5361e095096f833c6b25d900731189116423ed7d`: static validation (41393343638), static Pages deploy (41393343598), Pages build/deployment (41393342923).
- The old fixed-window counter table is currently retained but no longer used; its live row count was 0 before replacement. Keep it until a later reviewed cleanup migration; do not remove the HMAC key.


### Customer credit ledger hardened as append-only and audited — applied and verified (2026-11-02)
- Confirmed `shopkeeper.html` only reads and inserts `shop_credit_ledger`; no app update/delete path exists. The old `shop_credit_ledger_owner_all` policy permitted UPDATE and DELETE, and the table had no triggers.
- Applied migration `supabase/migrations/20261102270000_make_shop_credit_ledger_append_only_and_audited.sql`: replaced ALL policy with owner-scoped SELECT and INSERT policies; revoked UPDATE/DELETE from PUBLIC, anon, authenticated and service_role; added a database trigger that rejects UPDATE/DELETE with SQLSTATE 55000; added an AFTER INSERT audit trigger.
- The audit event records shop_id, entry_type, amount and entry_date only. Customer name, phone and notes are deliberately excluded from audit JSON.
- Transactional test passed: shop owner inserted a temporary adjustment; audit event was created; direct UPDATE and DELETE attempts as database owner were both blocked by the append-only trigger. Entire transaction rolled back; follow-up check confirmed 0 persisted test ledger rows and 0 test audit rows.
- Verified privileges: authenticated SELECT/INSERT true, UPDATE/DELETE false; anon SELECT/INSERT false. No existing ledger rows were present before migration; no business data was changed.
- Audit Trail coverage now includes order status, payment security-state, and customer-credit ledger insert events, plus explicit audit inserts in Owner and subscription RPCs. Remaining high-risk mutation paths still need a full event matrix.


### Credit-ledger subscription enforcement and owner-isolation test — applied and verified (2026-11-02)
- Tightened the credit-ledger INSERT policy so a new entry requires the authenticated owner of the shop, an active shopkeeper profile, `business_type='grocery'`, active shop status and a current subscription. SELECT remains owner-scoped so historical entries remain readable.
- Transaction tests passed: the real shop owner could insert a temporary adjustment and the audit trigger wrote the expected event; an unrelated authenticated customer attempting an insert was blocked by RLS. Both transactions rolled back; follow-up checks show 0 persisted test ledger rows and 0 persisted test audit rows.
- This closes the previous front-end-only subscription gate for ledger writes. No real ledger or customer data existed/was changed.
- CI for the policy migration commit `e5ed0c76107b401ec03d41d4ba079debe92fcbb0`: static validation passed (41393780189); static Pages deploy (41393780062) and Pages build/deployment (41393779854) were still in progress at the last poll.


### Super Admin Lock strengthened to require a live verified TOTP factor — applied and tested (2026-11-02)
- Added and applied `supabase/migrations/20261102290000_require_verified_totp_for_super_admin.sql`. `private.is_super_admin()` now requires all three conditions on every database authorization check: active `super_admin` profile, JWT AAL2, and at least one currently verified TOTP factor in `auth.mfa_factors`.
- This prevents a still-valid AAL2 JWT from retaining Owner permissions after the account's TOTP factor has been removed; the database checks current factor status, not just the token claim.
- SQL tests passed: Super Admin AAL1 denied; Super Admin AAL2 with no verified factor denied; non-admin AAL2 denied; shopkeeper own-shop check remains allowed at AAL1. All tests were rolled back/read-only.
- Live Super Admin factor inventory still shows 0 verified TOTP factors. Therefore Owner access is deliberately fail-closed until the account holder completes the TOTP enrollment/verification flow in `owner.html`. Positive authorization after a real verified factor and fresh AAL2 session remains pending and cannot be simulated by forging JWT claims.


### Remaining public anonymous intake endpoints protected by sliding-window limits — applied and tested (2026-11-02)
- Catalog review found exactly three additional public/anonymous INSERT policies: `electronics_service_jobs_public_insert`, `hotel_booking_requests_public_insert`, and `restaurant_reservations_public_insert`. Each now has a BEFORE INSERT database trigger that applies a concurrency-safe HMAC sliding-window limiter.
- Added/applied `supabase/migrations/20261102300000_rate_limit_public_booking_and_repair_intake.sql`. Limits are 5 requests per normalized phone number per shop/type and 120 requests per shop/type in any rolling 60-minute window. Request types are separated (electronics repair, hotel booking, restaurant reservation). Raw phone numbers are not stored in the rate-limit table.
- Test transaction created four temporary active category shops using the existing shopkeeper identity, then exercised the real anonymous INSERT policies and triggers: for Electronics, Hotel and Restaurant, 5 same-phone requests succeeded and the 6th was blocked; for a separate Restaurant shop, 120 unique-phone requests succeeded and the 121st was blocked. All requests, test shops and limiter events were rolled back; follow-up checks confirmed 0 persisted test shops, requests or rate-limit events.
- Verified anon/authenticated have no direct SELECT/INSERT access to the private rate-limit table and cannot directly execute the limiter helper. The only remaining public INSERT policies are these three, now protected; Digital Services uses its separately tested RPC limiter.
- CI for migration commit `c51db6ed8d8c0fd1b7cd697e255a2714aec179d0`: static validation passed (41394044242), static Pages deploy passed (41394044241), Pages build/deployment was still in progress at last poll.
- Anti-Brute-Force remains In Progress because Auth login and Razorpay Edge Function rate limits, IP/device-level controls and operational recovery tests remain open.


### Grocery financial ledgers protected and audited; shopkeeper UI grants repaired — applied and verified (2026-11-02)
- Added/applied `supabase/migrations/20261102310000_audit_and_protect_grocery_financial_ledgers.sql`. Supplier payments, stock purchases and stock movements now reject UPDATE/DELETE at trigger level. Inserts into those three ledgers and INSERT/UPDATE/DELETE on grocery expenses create compact `audit_logs` entries.
- Audit payloads include shop/product/supplier IDs, amounts, payment method/date, purchase quantities/costs, movement before/after stock, and expense category/date. They deliberately omit notes, reference numbers, supplier names and phone numbers.
- Transactional verification passed: supplier payment insert, `grocery_record_purchase` (stock purchase + stock movement), and grocery expense insert/update/delete each produced the expected audit event(s); UPDATE/DELETE attempts against supplier payments, stock purchases and stock movements were blocked with SQLSTATE 55000. All test rows and audit rows were rolled back. A focused follow-up confirmed both stock-purchase and stock-movement audit events are emitted.
- Found and fixed a separate least-privilege mismatch: `shopkeeper.html` uses SELECT/INSERT on `grocery_suppliers` and `grocery_expenses`, and SELECT on `grocery_stock_purchases` and `grocery_stock_movements`, but authenticated had no table privileges on those tables despite existing RLS policies. Applied `supabase/migrations/20261102320000_restore_least_privilege_grocery_read_insert_grants.sql`: granted exactly those UI-required privileges and removed unused supplier/expense UPDATE/DELETE policies. Authenticated now has SELECT/INSERT only on suppliers/expenses and SELECT only on purchases/movements; no UPDATE/DELETE grants.
- CI passed for the audit-trigger commit `10255d38d27be30038acd71f7230ead6e670bba4` (static validation 41394310258, deploy 41394314128, Pages build 41394308652) and the least-privilege grant commit `699b35ce7185f347425fff924d812df1532fee6b` (static validation 41394453671, deploy 41394453678, Pages build 41394453419).
- This strengthens Audit Trail and Database Fortress. Both features remain In Progress because other business mutation paths and full HTTP/API tests remain outstanding; the 10/10 completion gate is not yet met.


### Owner live audit alerts enabled — database publication and dashboard subscription added (2026-11-02)
- Added/applied `supabase/migrations/20261102330000_enable_owner_audit_realtime_alerts.sql`; `public.audit_logs` is now a member of `supabase_realtime` alongside `public.orders`.
- Updated `owner.html` (not `index.html`) to subscribe to INSERT events on `public.audit_logs` only after the Owner session passes profile, AAL2 and verified-TOTP checks. New events refresh the audit list and show a live in-dashboard alert; the channel is removed when the page returns to the login state.
- Verified `audit_logs` has authenticated SELECT privilege, no anon SELECT privilege, and one SELECT RLS policy backed by `private.is_super_admin()` (active Super Admin + AAL2 + currently verified TOTP). Realtime therefore uses the same Owner-only database authorization rather than a public channel.
- Static validation passed on commit `0014f4ae21f3999f438bded141c783477295ec09` (run 41394868277); the final status-document commit `f4898c8e33c714e8a0e9c2d56d906e51c7144f16` passed static validation (41394929524), Pages deploy (41394929544) and Pages build/deployment (41394928912).
- Live WebSocket receipt cannot be positively tested until the real Owner account enrolls and verifies TOTP; no verified factor is currently enrolled. This is in-app live audit alerting only. Failed-login alerts, out-of-app delivery, retry/deduplication and delivery monitoring remain open, so Real-Time Alerts is not Completed.


### Supabase Auth abuse-log evidence and alerting limitation — 2026-11-02
- Read-only review of the project's unified Auth logs for the last 24 hours found 7 `invalid_credentials` responses (HTTP 400) and 4 `over_email_send_rate_limit` responses (HTTP 429) for recovery-email requests. This confirms Supabase's recovery-email rate limiter is actively returning 429s; it does not prove a configurable password-login lockout policy.
- `auth.audit_log_entries` currently has 0 rows and no trigger. The Auth login/recovery events are visible in the external `auth_audit_logs` / `auth_logs` log streams, not as database rows that the current `audit_logs` Realtime subscription can consume.
- Therefore the Owner's live audit feed covers database audit events only. Failed-login alerts require a supported log-drain/management-API integration and a configured trusted destination; do not claim failed-login alerting is complete.
- No email addresses, IP addresses, user agents or raw log payloads were copied into the project status. Log queries were read-only.


### Razorpay webhook request-body DoS hardening — tested and deployed (2026-11-02)
- The webhook previously called `req.text()` without a size limit. Replaced it with `readBodyLimited()` that rejects declared or streamed bodies above 1 MiB (HTTP 413), rejects malformed Content-Length (HTTP 400), and preserves exact request bytes for HMAC-SHA256 verification.
- Moved raw-byte HMAC and constant-time comparison helpers into `supabase/functions/razorpay-payment-webhook/security-utils.js`; added `tests/webhook-security.test.mjs` and wired it into `.github/workflows/static-validation.yml`.
- Node unit tests passed in GitHub Actions run `41395363868`: body under limit, declared oversize, streamed oversize, exact-limit acceptance, malformed Content-Length, standard HMAC-SHA256 vector and signature comparison.
- Deployed `razorpay-payment-webhook` version 9; verified active deployment, `verify_jwt=false` (intentional because the handler authenticates with Razorpay HMAC), body cap and raw-byte HMAC in deployed source. No checkout, payment state transition or subscription activation logic was changed.
- Pages build/deployment passed for commit `59f2cf51c01b36255a54341d77995e270b9df317` (41395363491); static validation passed (41395363868). The Pages deploy job was still pending at last poll.
- This is a request-size/DoS hardening and unit-test result, not an end-to-end Razorpay signature/replay test. Real signed webhook, invalid-signature HTTP response, duplicate delivery and concurrent callback tests remain open; Payment Shield remains In Progress.


### Least-privilege grants for shopkeeper business modules and private limiter deny policies — applied and verified (2026-11-02)
- Source review of `shopkeeper.html` found seven business tables with actual SELECT/UPDATE or SELECT/INSERT/UPDATE calls but no authenticated table privileges: `electronics_service_jobs`, `hotel_booking_requests`, `hotel_housekeeping_tasks`, `office_leave_requests`, `office_payroll_records`, `office_tasks`, and `restaurant_reservations`.
- Added/applied `supabase/migrations/20261102330000_restore_business_module_least_privilege_grants.sql`. Granted only the operations used by the UI, with no DELETE grants. Existing owner-scoped RLS policies remain in force. Verified the exact privilege matrix after application.
- Supabase Security Advisor flagged five private rate-limit tables for RLS enabled with no policies. Although this was already default-deny and none of anon/authenticated had table privileges, added explicit `FOR ALL TO PUBLIC USING(false) WITH CHECK(false)` policies in `supabase/migrations/20261102340000_explicit_deny_policies_private_rate_limit_tables.sql`. Verified all five have explicit deny policies and no anon/authenticated table grants.
- Security Advisor now reports only the Auth leaked-password-protection warning; it no longer reports the five private-table RLS findings. This setting is plan-gated on the current Free organization and remains an external prerequisite, not a code change.
- CI: static validation passed for the grant commit `11ccde6020b49c95d680f8ef52ef7697352c4532` (run 41395698980) and deny-policy commit `702da6ca9266c1d213102312ac5cd633e4341860` (run 41395761900). Pages deployment/build were still running at last poll.
- These are targeted permission and policy improvements, not proof of full HTTP/API tenant isolation. Database Fortress and Anti-Brute-Force remain In Progress; no Security Shield item is promoted to fully complete.


### Owner-scoped shop application INSERT permission restored and tested — applied (2026-11-02)
- `apply-shop.html` submits new shop applications with a direct authenticated INSERT into `public.shops`, but the authenticated role had no INSERT table privilege even though a strict `shops_insert` RLS policy and a BEFORE INSERT activation-guard trigger were already present.
- Added/applied `supabase/migrations/20261102350000_restore_owner_scoped_shop_application_insert.sql`, granting only INSERT to `authenticated`; anon INSERT remains denied.
- Transaction test as the existing authenticated shop owner inserted a temporary application while deliberately supplying `is_active=true`, `status='active'`, a subscription plan and future expiry. The database trigger forced the row to `is_active=false`, `status='inactive'`, `subscription_plan_id=NULL`, `subscription_expires_at=NULL`. A subsequent owner attempt to activate the shop directly was blocked with SQLSTATE 42501. Transaction rolled back; follow-up confirmed 0 persisted test rows. This preserves the normal owner-review/payment activation gate.
- This fixes an app/database permission mismatch without changing the application UI or granting any activation authority. HTTP/PostgREST regression test is still pending.


### Latest deployment and regression CI confirmation — 2026-11-02
- GitHub Actions completed successfully for shop-application permission migration commit `0e1d735f42017cf14eb5eb19a3322cd6de67d685`: static validation run `41396151908`, Pages deployment run `41396151828`, and Pages build/deployment run `41396148318` all passed.
- The follow-up `PROJECT_STATUS.md` commit `2616efa15ce04d6ddff3ab2aa9084b70d854ca8e` also passed static validation (`41396240659`), Pages deployment (`41396240690`) and Pages build/deployment (`41396240487`).
- Static CI and Pages deployment are green for the current repo head at this checkpoint. This does not substitute for authenticated HTTP/PostgREST tests or live Owner MFA enrollment.


### Anonymous catalog data minimization and public booking RLS split — applied and tested (2026-11-02)
- A fresh `has_column_privilege` audit showed anonymous table-level SELECT on public catalog tables was allowing every column, including shop `owner_id`, phone/email/address, subscription plan/expiry and monthly order counters; product `offer_text`/slug; hotel room numbers; plan slugs/IDs; and jewellery certificate/hallmark fields. RLS row filtering did not limit which columns could be selected.
- Added/applied `supabase/migrations/20261102360000_minimize_anonymous_catalog_column_access.sql`. Revoked all anon/PUBLIC table privileges (including PostgreSQL 17 MAINTAIN) from shops, products, categories, hotel_rooms and subscription_plans, then granted only the columns required by current public pages. Anonymous SELECT was fully revoked from garment variants, jewellery details, restaurant menu items, restaurant tables and subcategories, which have no current public-page query.
- The public pages' actual query fields and filters/order columns were inventoried before selecting the allowlist: shops `id,name,city,business_type,status,is_active`; products `id,shop_id,category_id,name,description,price,sale_price,stock,images,is_available,created_at`; categories `id,name,is_active,business_type`; hotel rooms `id,shop_id,room_type,capacity,base_rate,room_status,is_active`; plans `name,price_monthly,price_yearly,max_products,max_orders_per_month,features,is_active`.
- This surfaced a second issue: the old hotel-room SELECT policy applied `private.is_shop_owner()` to anon, but anon is intentionally not allowed to execute that helper. Split the policy so anon uses only `is_active=true AND private.is_public_shop_active(shop_id)` and authenticated retains owner/Super Admin/public-active access. Changed the other non-public catalog extension read policies to authenticated-only. Applied `supabase/migrations/20261102370000_split_public_catalog_read_policies.sql`.
- Verification as database role `anon` passed for the exact public catalog query shapes (including products joined to shops, category filters, hotel room query, and active plans). Negative column tests passed: shop phone, owner ID, subscription expiry, product offer_text, hotel room number and plan slug are denied. Anonymous access to restaurant tables, jewellery details, garment variants, restaurant menu items and subcategories is denied. A transaction created a temporary active hotel and room; anon could read public hotel name/city and room type/capacity/rate, but could not read phone or room number. All test rows were rolled back; follow-up confirmed 0 temporary rows.
- Live anonymous catalog role test returned the expected public rows (1 active shop, 1 public product, 4 active grocery categories, 3 active plans). Supabase Security Advisor still reports only the plan-gated leaked-password-protection warning.
- CI passed for column-minimization commit `34a7a0ecc112faeee8f2452832d6118e4ec28d72` (static validation 41396757919, Pages deploy 41396757862, Pages build 41396757926) and policy-split commit `e783cc5e7a21256991bae910a5f89146488301c8` (static validation 41396881114, Pages deploy 41396881081, Pages build 41396880494).
- This is verified SQL-role/privilege testing, not a full browser HTTP/PostgREST test. Database Fortress remains In Progress and the 10/10 gate remains locked.


### Operational business-module audit trail expanded and tested — applied (2026-11-02)
- Added/applied `supabase/migrations/20261102061000_audit_business_module_mutations.sql` with a private SECURITY DEFINER trigger function and AFTER INSERT/UPDATE/DELETE triggers for `electronics_service_jobs`, `hotel_booking_requests`, `hotel_housekeeping_tasks`, `office_leave_requests`, `office_payroll_records`, `office_tasks`, and `restaurant_reservations`.
- Per-table payload allowlists record shop/entity IDs and operational lifecycle fields. Customer/guest names, phone numbers, device issue/IMEI fields, free-form notes/reasons/descriptions, employee names, payroll amounts and payment references are intentionally excluded.
- Transactional verification passed for all seven tables: each emitted exactly one create, one update and one delete event (21 total). Negative payload scan confirmed all seeded PII/notes/payroll amounts were absent. The transaction was rolled back; follow-up confirmed 0 temporary business rows and 0 temporary audit rows remain.
- Separate visibility simulation: the existing shopkeeper saw exactly one fixture row in each of the seven module tables; an unrelated authenticated customer saw zero in all seven. Fixture transaction rolled back. This is a SQL role simulation, not HTTP/PostgREST tenant testing.
- Audit Trail remains In Progress; full event coverage for all remaining business tables, retention controls and alert linkage are still open. No Security Shield feature is marked fully completed.


### Two-tenant isolation verified across seven additional operational tables — 2026-11-02
- Built two synthetic shopkeeper identities and separate active test shops for Electronics, Hotel, Office/Company and Restaurant inside one SQL transaction. Created tenant-specific repair jobs, hotel booking requests, housekeeping tasks, office leave requests, payroll records, office tasks and restaurant reservations.
- Under authenticated Tenant A claims, each of the seven tables returned only Tenant A's fixture row (count 1). Under Tenant B claims, each returned only Tenant B's fixture row (count 1). An unrelated authenticated customer saw count 0 in all seven tables.
- All fixtures, including the synthetic Auth user/profile, shops, related rooms/employees, operational rows and generated audit events, were rolled back. Independent cleanup query confirmed 0 test Auth users, profiles, shops, repair jobs and audit rows remain.
- This extends Zero-Trust/Database Fortress SQL evidence. It is not a live HTTP/PostgREST test, and neither feature is marked Completed.


### Audit logging expanded to 28 public tables — applied and verified (2026-11-02)
- Added/applied `supabase/migrations/20261102062000_audit_catalog_inventory_and_operations.sql`. The private audit trigger now covers 21 additional tables: categories, subcategories, products, Digital Seva applications, electronics inventory, garment variants, jewellery details, medical batches, hotel rooms/reservations, office employees/attendance, grocery suppliers, delivery addresses, platform settings, subscription plans, shop subscriptions, restaurant tables/menu items/kitchen tickets/ticket items. Together with the previous seven operational tables, 28 tables now have `audit_business_module_mutations` triggers.
- Payloads use table-specific field allowlists. Sensitive fields are deliberately excluded, including delivery address/phone/pincode, applicant/customer/guest names and phones, device IMEI/serial, employee names/phone/salary, free-form notes/descriptions, platform setting values/secrets, certificate/hallmark references and kitchen guest names.
- Transactional create/update/delete verification produced 30 events across 10 representative tables. A separate privacy allowlist test produced 9 events across electronics inventory, delivery addresses and platform settings and confirmed no forbidden sensitive keys were present. Both test transactions rolled back; independent cleanup checks returned 0 test rows and 0 audit rows.
- Verified 28 trigger attachments across 28 distinct public tables. The shared trigger function has no direct EXECUTE privilege for anon/authenticated, and authenticated has no direct INSERT privilege on `audit_logs`.
- CI passed for migration commit `539b9c3e407e439d31adc348fa27d54de507cef6`: static validation run `41398949283`, Pages deployment run `41398949271`, Pages build/deployment run `41398949308`. The subsequent two-tenant status-document commit `0d3f1813fe4eb44789e52740dfbcaabc4c3a29ec` also passed static validation (`41398725049`), Pages deployment (`41398725068`) and Pages build/deployment (`41398725410`).
- Audit Trail remains In Progress: remaining mutation tables, retention/immutability review, event delivery monitoring and external failed-login alert integration still need evidence. No Security Shield item is promoted to fully Completed.


### Secret Vault current-tree and sensitive-path history scan — 2026-11-02
- Scanned all 30 tracked HTML, JavaScript, TypeScript, JSON, YAML and Markdown files in the current repository tree for common `sb_secret_` keys, service-role assignments, Razorpay secret assignments/key patterns, private-key PEM blocks, OpenAI-style secret keys and JWT-like literals. No matches were found.
- Queried GitHub commit history for `.env`, `.env.local`, `.env.production`, `supabase/.env`, `service_role_key.txt`, `secrets.json`, `razorpay_keys.txt` and `supabase/config.toml`; each path returned zero commits.
- This is not a complete historical blob scan and does not establish that no secret was ever committed under another filename or encoded form. Secret Vault remains In Progress; full Git-history scanning, external credential inventory and rotation review remain required. No secret values were printed or changed.


### Automated reachable-Git-history secret scan added to CI and passed — 2026-11-02
- Added `scripts/scan-secret-history.mjs` and changed `.github/workflows/static-validation.yml` to use full checkout history (`fetch-depth: 0`) and run the scanner on every push/PR.
- Scanner checks reachable Git patch history for Supabase secret keys, Razorpay live/test keys and secret assignments, service-role key assignments, AWS access keys, Google API keys, GitHub personal access tokens, Slack tokens, private-key PEM headers, and JWTs whose decoded payload has `role=service_role`. It reports file/pattern only, never matched values.
- GitHub Actions static validation passed on commit `2865092ac5fdc87a5d4249969ebd65af97d56392` (run `41399822958`): history scan passed, 283 static checks passed, and all 7 webhook unit tests passed. Pages deployment/build were still running at last poll.
- This scans reachable Git patch history against configured patterns, not every possible credential format or unreachable Git object. Secret Vault remains In Progress pending external credential inventory, key rotation review and any required historical cleanup.
