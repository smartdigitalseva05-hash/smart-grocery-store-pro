# Smart Business Pro — Security Shield Specification

**Priority:** Critical / mandatory for every module  
**Status:** Mandatory architecture recorded; the 10-feature Security Shield is the only active implementation module until all controls pass evidence-based verification. See the execution lock in PROJECT_STATUS.md.

## Security objective
Use defense in depth and zero-trust authorization to reduce the risk of account takeover, unauthorized access, data exposure, payment fraud, and destructive actions. No system can honestly be guaranteed 100% unhackable; security must be continuously tested and maintained.

## Mandatory security controls

1. **Zero-trust authorization**
   - Authenticate and authorize every sensitive request on the server/database.
   - Never trust hidden buttons, client-side role checks, URL parameters, or browser storage as proof of permission.
   - Enforce shop ownership and tenant isolation on every read and write.

2. **Super Admin protection**
   - Require MFA for Super Admin accounts and step-up re-authentication for high-risk actions where supported.
   - Keep Owner privileges in trusted server-side authorization data; never use user-editable user metadata for roles.
   - Apply least privilege, session expiry/revocation procedures, and explicit confirmation for destructive actions.

3. **Supabase database security**
   - Keep RLS enabled on every exposed table.
   - Review each policy for owner/shop isolation, role escalation, anonymous access, and correct UPDATE USING plus WITH CHECK predicates.
   - Review views, RPCs and Edge Functions for privilege escalation; prefer SECURITY INVOKER. Restrict and audit any necessary SECURITY DEFINER function.
   - Review Storage bucket policies and private document access separately.

4. **Secrets and key protection**
   - Never place service-role keys, secret API keys, Razorpay secrets, passwords, or signing keys in frontend code, public repositories, logs, or client storage.
   - Store secrets only in server-side environment/Edge Function secrets; rotate immediately if exposed.
   - Use only publishable/anon keys in browser code, with RLS as the actual data boundary.

5. **Authentication and abuse prevention**
   - Enable Supabase leaked-password protection and strong password settings.
   - Add appropriate rate limits, progressive delays/temporary lockouts, abuse monitoring, and safe account recovery.
   - Validate sessions on sensitive operations; revoke sessions on account compromise or role changes as appropriate.

6. **Application attack-surface protection**
   - Validate and constrain all input on the server; use parameterized database operations.
   - Apply context-appropriate output encoding and Content Security Policy; protect state-changing browser requests against CSRF where applicable.
   - Prevent XSS, SQL injection, IDOR/BOLA, unsafe file uploads, open redirects, and mass-assignment vulnerabilities.
   - Pin dependencies, maintain lockfiles, and review dependency/security alerts.

7. **Payments**
   - Verify Razorpay webhook signatures against the exact raw request body using server-side secrets.
   - Enforce amount, currency, order/subscription matching, event authenticity, idempotency, replay resistance, and concurrency-safe processing.
   - Never trust client-reported payment success.

8. **Monitoring and recovery**
   - Record security-relevant events in tamper-resistant, access-controlled audit logs without logging secrets or unnecessary personal data.
   - Alert on suspicious sign-ins, repeated failures, privilege changes, unusual payment events, and sensitive admin actions.
   - Maintain encrypted backups, retention rules, and a documented restore procedure; periodically verify restoration.


## The 10 mandatory Security Shield features (owner-approved)

These are the exact ten features. All ten are mandatory; none may be omitted or treated as optional.

1. **Zero-Trust Security** — verify identity, session validity, role, resource ownership and permission on every protected request at the trusted server/database layer.
2. **Super Admin Lock** — require MFA for Owner/Super Admin and fresh re-authentication for sensitive actions; enforce server-side role checks and safe session revocation.
3. **Database Fortress** — enforce Supabase RLS on exposed tables, least-privilege grants, correct tenant/shop isolation, secure RPC/view/Storage policies and server-side authorization.
4. **Anti-Brute-Force** — apply login and sensitive-endpoint rate limits, progressive delays or temporary lockout, abuse detection and safe recovery controls.
5. **Secret Vault** — keep service-role keys, Razorpay secrets, signing keys and credentials only in server-side secret storage; scan repository/history and rotate any exposed secret.
6. **Attack Protection** — server-side validation, parameterized queries, output encoding, CSP and applicable CSRF protections; test XSS, SQL injection, IDOR/BOLA, open redirects, unsafe uploads and mass assignment.
7. **Real-Time Alerts** — detect and alert on suspicious sign-ins, repeated failures, privilege changes, unusual payment events and sensitive Owner actions, with protected alert delivery.
8. **Backup & Recovery** — encrypted backups, restricted access, retention policy, documented recovery objectives and periodic restore drills.
9. **Audit Trail** — access-controlled, tamper-resistant records of who performed which security-relevant action and when; exclude secrets and unnecessary personal data.
10. **Payment Shield** — verify Razorpay webhook signatures using the raw request body and server-side secret; validate amount/currency/order, enforce idempotency and replay/concurrency protection, and never trust client payment status.

## Ten-feature completion gate

Maintain a separate status and evidence for each of the ten features in `PROJECT_STATUS.md`. A feature is **Completed** only after implementation and relevant automated/API/security tests pass. Until then it must remain **Pending** or **In Progress**. The whole Security Shield is Completed only when all ten pass their acceptance checks and deployment/security review is verified.

## Required verification before Security Module can be marked Completed
- RLS/policy matrix tests for signed-out, customer, shopkeeper, shop owner, and Super Admin roles.
- Cross-shop IDOR/BOLA tests for reads, writes, storage, RPCs, and Edge Functions.
- Auth tests for MFA, leaked passwords, session expiry/revocation, password reset, and role escalation.
- Secret scanning of current repository and history; rotate any exposed credentials.
- Negative tests for XSS, injection, CSRF, unsafe uploads, rate limits, and authorization bypass.
- Razorpay tests for invalid signatures, duplicate/replayed events, wrong amount/currency/order, and concurrent delivery.
- Backup restore drill, audit-log access review, Supabase Security Advisor review, static checks, and deployment verification.

## Implementation discipline
- Preserve existing `index.html`, data, schema, and working flows unless a reviewed change is required.
- Make changes in small, reviewable steps. Do not weaken an existing policy to make a feature work.
- Never expose a new control until its server-side permission check and audit behavior are verified.
- Track each control as Pending / In Progress / Completed with evidence in `PROJECT_STATUS.md`.
- Do not claim “100% hack-proof.” Report exactly what was implemented, tested, and remains outstanding.
