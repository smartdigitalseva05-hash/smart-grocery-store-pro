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
