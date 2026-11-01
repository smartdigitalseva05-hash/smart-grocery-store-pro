# Smart Business Pro — Project Status

**Last updated:** 2026-11-01

## Current active work

**Module 1 — Business Category Module (functional implementation).**

The immediate goal is to make all 11 business categories work as real category-based flows, not just display cards. A parallel read-only security audit has also started so new functionality is not built on unreviewed access controls.

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
- Database inspection found **40 public tables**; all 40 currently have RLS enabled and at least one RLS policy. This is a positive baseline, not proof that every policy is correct.
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

1. Category Module — finish category selection, category mapping, and category-aware flows.
2. Security & Protection Module — finish critical access-control and secret-handling review before expanding live shop workflows.
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
