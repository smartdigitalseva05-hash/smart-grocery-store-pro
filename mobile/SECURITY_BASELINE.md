# Mobile security baseline

- Enforce Supabase Row Level Security for every tenant-owned record.
- Enforce role checks server-side; the app package, route, local storage and UI visibility are not authorization.
- Require Owner MFA and fresh authentication for sensitive Owner actions.
- Keep all gateway secrets and Supabase privileged keys server-side only.
- Validate Razorpay signatures server-side and make payment processing idempotent.
- Use HTTPS only; reject untrusted hosts and unsafe URL schemes.
- Disable WebView file access, content access, mixed content and debugging in release builds.
- Do not add permissive JavaScript interfaces to the WebView.
- Avoid logging access tokens, OTPs, payment data or personal customer data.
- Provide session logout and clear app-owned session data on explicit logout.
- Protect release signing keys; never commit keystores or passwords.
- Add dependency, manifest and secret scanning to CI before production release.
- Complete real-account tests for Owner, Shopkeeper and Customer isolation before launch.

A green build is not proof of security. Security acceptance requires policy review, automated checks and end-to-end tests.
