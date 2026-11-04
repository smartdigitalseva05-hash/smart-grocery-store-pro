# Smart Business Pro — Android App Suite

This directory is the isolated foundation for three separately distributable Android apps. It is intentionally separate from the existing website and the current Owner APK workflow.

## Apps

| App | Android application ID | Web entry point | Audience |
|---|---|---|---|
| Owner | `com.smartbusinesspro.owner` | `/smart-grocery-store-pro/owner.html` | Owner only |
| Shopkeeper | `com.smartbusinesspro.shopkeeper` | `/smart-grocery-store-pro/shopkeeper.html` | Approved shopkeepers |
| Customer | `com.smartbusinesspro.customer` | `/smart-grocery-store-pro/index.html` | Customers |

## Safety rules

- Do not replace or rename the existing root `index.html`, website pages, Supabase migrations, or data.
- Each app has its own package ID, app label, launcher icon and release artifact.
- Web authentication, Supabase RLS, server-side authorization and Owner MFA remain authoritative. The Android shell must never grant roles or bypass these controls.
- Never bundle Supabase service-role keys, Razorpay secrets, passwords, or signing credentials in source code or APKs.
- Only HTTPS is allowed in the embedded web view. File access and mixed content stay disabled.
- External links open outside the app; only the exact approved site origin and app route are kept inside.
- Debug APKs are for internal testing only. Public distribution requires a protected release-signing process and Play App Signing.
- Do not claim Play Protect warnings are eliminated merely by changing the APK label or icon.

## Current status

This is a source-controlled foundation/architecture scaffold, not three completed or tested APKs. The existing Owner APK workflow remains unchanged on `main`. Build and device acceptance tests are still required before public release.

## Next implementation sequence

1. Add shared Android build configuration and three independent app modules.
2. Add exact approved URLs, secure navigation allowlists, offline/error states and lifecycle handling.
3. Integrate the user's original approved brand assets into all launcher icons and splash screens.
4. Add CI builds and separate signed release tracks; keep signing keys in GitHub Actions secrets or Play App Signing.
5. Run automated checks, then test sign-in, MFA, shop isolation, customer catalogue isolation, checkout and logout on real devices.
6. Publish internal testing builds before any public rollout.
