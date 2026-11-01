# Smart Business Pro — Security Shield Specification

**Priority:** Critical / mandatory for every module  
**Status:** Architecture requirements recorded; implementation and verification are still pending.

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
