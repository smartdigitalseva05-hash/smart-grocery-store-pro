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
