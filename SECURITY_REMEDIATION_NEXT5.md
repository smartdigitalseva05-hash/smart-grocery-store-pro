# Smart Business Pro — Next 5 Security Features Remediation

**Audit date:** 2026-11-01  
**Scope:** Super Admin Lock, Anti-Brute-Force, Attack Protection, Real-Time Alerts, Backup & Recovery  
**Status:** Audit started; implementation and evidence-based verification remain in progress.

## 1. Super Admin Lock
**Observed:** The current read-only audit has not yet established whether MFA is enforced for every Super Admin account or whether sensitive Owner RPCs require a fresh MFA/AAL2 session.

**Implementation requirements**
- Enforce MFA enrollment and assurance level for Super Admin accounts.
- Require fresh re-authentication/step-up for sensitive actions (role changes, shop suspension, payment/refund actions, secrets/configuration and destructive operations).
- Enforce checks inside trusted RPC/Edge Function/database code, not just by hiding UI controls.
- Revoke sessions after role removal, account compromise or credential reset where appropriate.
- Keep role claims in trusted app metadata/private database records, never user-editable metadata.

**Acceptance tests:** Non-MFA Owner denied sensitive action; MFA Owner allowed; Shopkeeper/Customer denied; expired/revoked session denied; role downgrade takes effect.

## 2. Anti-Brute-Force
**Observed:** The three inspected Razorpay Edge Function handlers do not show an app-level rate limiter. Platform-level Auth/API protections still need separate settings inspection.

**Implementation requirements**
- Verify Supabase Auth rate-limit settings and email/OTP limits.
- Add server-side per-account and per-IP limits for sensitive custom endpoints, with progressive delays and bounded temporary lockouts.
- Avoid permanent lockout and provide safe account recovery.
- Record abuse signals without storing passwords, tokens or unnecessary personal data.
- Ensure limits are shared/atomic across instances (not in-memory counters).

**Acceptance tests:** Threshold enforcement, reset/window behavior, distributed/concurrent requests, legitimate recovery, and no bypass by changing client-side identifiers.

## 3. Attack Protection
**Observed in inspected Razorpay functions:**
- Checkout and verification require JWT and call Auth getUser.
- Request JSON/object and key payment identifiers are validated.
- Webhook validates the exact raw-body HMAC-SHA256 signature using a constant-time comparison.
- Checkout and verification currently set wildcard CORS (Access-Control-Allow-Origin: *).
- No explicit request-body size cap was evident in the inspected handlers.

**Implementation requirements**
- Restrict browser CORS to exact production origins; keep webhook server-to-server behavior separate.
- Enforce request size/content-type/method limits before parsing.
- Validate all data server-side; use parameterized database operations.
- Review output encoding, CSP, CSRF applicability, redirect allowlists, file type/size scanning and ownership checks.
- Review every HTML page, RPC and Edge Function for XSS, SQLi, IDOR/BOLA, mass assignment and unsafe upload paths.

**Acceptance tests:** Malformed/oversized body, disallowed origin, invalid identifiers, reflected/stored XSS payloads, SQLi payloads, cross-shop resource IDs, unsafe file types and unauthorized redirects are rejected safely.

## 4. Real-Time Alerts
**Observed:** No end-to-end alert creation and delivery pipeline has yet been verified.

**Implementation requirements**
- Define events: suspicious sign-in, repeated failed authentication, MFA changes, Owner role changes, sensitive Owner actions, unusual/failed payment and webhook anomalies.
- Send alerts through a server-side trusted channel; do not expose provider secrets to the browser.
- Protect alert records and delivery configuration with least privilege.
- Deduplicate noisy events, retain delivery status, and avoid secrets/credential contents in logs.
- Provide an Owner-only searchable alert view with safe pagination.

**Acceptance tests:** Trigger each event, verify authorized recipient and delivery, reject unauthorized alert reads, verify deduplication/retry and confirm secrets are not logged.

## 5. Backup & Recovery
**Observed:** Backup configuration, retention, encryption and a successful restore drill have not yet been verified.

**Implementation requirements**
- Confirm the actual Supabase plan's backup/PITR capabilities and schedule.
- Document database and Storage backup coverage separately.
- Restrict backup access; confirm encryption, retention and recovery point/time objectives.
- Keep recovery credentials outside the public repository and frontend.
- Perform a restore drill into a safe non-production target and verify row counts, relationships, Storage objects and application access.

**Acceptance tests:** Evidence of a recent backup, controlled restore, integrity checks and documented recovery steps. A configured backup without a successful restore drill is not Completed.

## Cross-feature safeguards
- Do not weaken existing RLS, Owner RPC checks, payment verification or JWT requirements.
- Do not deploy a breaking MFA/CORS/rate-limit change without confirming legitimate callers and recovery access.
- Never put service-role keys, Razorpay secrets, tokens or passwords in GitHub or frontend code.
- Keep all five features In Progress until implementation and automated/API verification evidence is recorded in PROJECT_STATUS.md.
- No claim of 100% hack-proof security.


## Follow-up audit evidence — 2026-11-01
- Project reports ACTIVE_HEALTHY and the owning organization is on the Free tier. Do not assume a backup schedule or PITR entitlement from this; confirm actual backup/restore availability in the dashboard and conduct a restore drill.
- Read-only catalog inspection confirms RLS enabled for `profiles`, `shops`, `audit_logs`, and `payments`; policy counts are 2, 5, 2, and 1 respectively. These are structural checks only, not a proof that policy predicates are correct.
- `audit_logs` currently has admin SELECT and admin INSERT policies. Verify that only trusted server-side paths can create audit events, that sensitive events are covered, and that users cannot alter/delete records.
- MFA enforcement configuration and successful backup restoration remain unverified. The Security Advisor still flags leaked-password protection as disabled.
- No production settings, data, schema, Edge Functions, secrets, or HTML pages were modified during this read-only follow-up.


## Follow-up audit — 2026-11-02

- Current Supabase catalog query found 41 public tables, with RLS enabled and at least one policy on every table; no UPDATE policy was missing WITH CHECK.
- Seven public/anon mutation policies were enumerated. The policies are constrained to authenticated row ownership/private Super Admin authorization or narrowly scoped customer-request INSERT rules; direct order INSERT is denied. Negative API tests are still needed to prove these conditions across actual roles and sessions.
- Four non-internal triggers exist on `shops`, including protected activation changes, business-type immutability for non-admins, and subscription-expiry tamper protection.
- Supabase project is ACTIVE_HEALTHY on the Free tier. Supabase official documentation states leaked-password protection is available on Pro and above; this item is plan-gated until the tier supports it and the setting is verified: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- The expanded static validator checks local links/assets, new-tab opener safety and common private credential patterns. It passed 283 checks across 14 HTML pages, 1 public script and all 11 business categories on commit `ab83f827e611403b6d786fddef5d0a90669a9a31` (GitHub Actions run `41377126260`). The Pages deployment/build for that commit was still pending at the time of this update.
- No production schema, policies, Auth settings, Edge Functions, secrets or business/payment records were modified by this audit.


## Expanded database privilege and backup review — 2026-11-02

- Catalog query: 71 functions in public/private schemas; 43 are SECURITY DEFINER. 32 SECURITY DEFINER functions have a function-level search_path that includes public; 17 are executable by anon according to PostgreSQL privilege checks.
- The private schema currently grants USAGE to anon and authenticated. This requires immediate exposure/caller review. It does **not** establish that every function is remotely callable: confirm whether private is in Supabase API exposed schemas and map existing legitimate callers before changing grants. Do not revoke access until customer-facing anonymous request flows have been checked.
- Review each SECURITY DEFINER function for explicit authorization, safe search_path, qualified object names, and least-privilege EXECUTE grants. The inspected Owner RPCs include private.is_super_admin() checks; payment activation permits service-role or active Super Admin. These individual code checks still need role-based negative API tests.
- Targeted public view catalog query returned no rows. PostgreSQL row_security is ON. API exposed-schema configuration was not available from the database settings query and must be checked in Supabase API settings.
- Supabase official backup documentation: daily managed backups are for Pro/Team/Enterprise. Free-tier projects should use Supabase CLI db dump and off-site backups; database backups do not include Storage objects. Until manual database and Storage export/restore are demonstrated, Backup & Recovery remains Blocked for managed backups and In Progress for a manual recovery implementation. https://supabase.com/docs/guides/platform/backups
- No database privileges, schema, functions, Auth settings, secrets, or application records were changed during this review.


## Verified execution update — 2026-11-02 08:12 UTC

- Applied migration `20261102080828` (`harden_grocery_expense_update_tenant_integrity`). The live `grocery_expenses_update` policy now has a restrictive `USING` and matching `WITH CHECK` for an active Grocery shop. A `SECURITY INVOKER` trigger with an empty search path prevents authenticated changes to `shop_id` and `created_by`. Live catalog inspection confirms the policy and trigger are installed.
- The production frontend origin was confirmed from the shopkeeper password-reset redirect and Pages deployment: `https://smartdigitalseva05-hash.github.io`. Checkout and verification CORS were restricted from wildcard to this exact origin with `Vary: Origin`.
- Checkout and verification now use the repository's 16 KiB streaming request-body limit helper. Deployed versions: checkout v11 and verification v9; both retain `verify_jwt=true`.
- GitHub Actions static validation passed on commit `ee80b0eaf3710619db23e02c983be1c2681db478`. The Pages workflow's Deno Edge Function type-check, HTML validation and deployment also passed. The customer-facing `index.html` was not modified.
- The Super Admin MFA audit found zero verified TOTP factors for the active Super Admin account. This is an Owner enrollment dependency; do not bypass the AAL2/TOTP requirement. Leaked-password protection remains plan-gated on the current Free tier.
- Remaining gates: disallowed-origin/oversized-body live HTTP tests, payment abuse rate limits, real Razorpay signature/replay/concurrency tests, MFA enrollment and sensitive-operation API tests, and verified manual database plus Storage backup/restore.

## Audit coverage update — 2026-11-02 08:14 UTC

- Supabase records migration `20261102081352` for audit coverage of `profiles`, `shops`, and `shop_trials` security-sensitive changes.
- Catalog verification confirms all three triggers are installed. Their shared function is `SECURITY DEFINER` with an empty search path, and direct EXECUTE is denied to `anon` and `authenticated`.
- Total trigger-based audit coverage is now 38 public tables. Only allowlisted security fields are captured; contact details are excluded.
- The matching SQL source file still needs to be synchronized into the GitHub migrations directory, and the new triggers still need a controlled behavior/API test before the Audit Trail feature can be marked Completed.

## Payment abuse protection update — 2026-11-02 08:16 UTC

- Applied Supabase migration `20261102081537` (`add_payment_endpoint_rate_limits`). It creates a private rate-limit event store and a server-only RPC. The public wrapper is executable by `service_role` only; SQL privilege checks confirm `anon=false`, `authenticated=false`, `service_role=true`.
- Checkout is limited to 5 requests per account per rolling 15 minutes; payment verification is limited to 10 per account per rolling 15 minutes. Advisory transaction locks serialize requests for the same account/action. Old event rows are pruned after 24 hours.
- SQL threshold tests passed: checkout request 6 was rejected with PT429 after 5 accepted requests; verification request 11 was rejected after 10 accepted requests. Synthetic test rows were removed in the sequential tests. A concurrent stress test remains pending.
- Deployed checkout v12 and verification v10. Both retain JWT verification, restrict CORS to the production GitHub Pages origin, require JSON, cap request bodies at 16 KiB, and fail closed with HTTP 503 if the rate-limit service is unavailable.
- The GitHub regression suite now checks the CORS allowlist, body cap, JSON content type and rate-limit enforcement. Full live HTTP tests and actual Razorpay transaction tests remain open.
- SQL source-file synchronization for the newly applied audit and payment-rate-limit migrations remains a repository maintenance gate; the live Supabase migration history records both changes.

## Private limiter table hardening — 2026-11-02 08:19 UTC

- Applied migration `20261102081910` to add an explicit deny-all policy for `anon` and `authenticated` on the private payment rate-limit event table. The server-only security-definer function remains the sole intended write path.
- Supabase Security Advisor now reports only the leaked-password-protection warning, which is plan-gated on the current Free tier; the private-table no-policy informational finding is cleared.
- Migrations `20261102081352`, `20261102081537`, and `20261102081910` are present in live Supabase migration history. Their SQL source files still need repository synchronization.
