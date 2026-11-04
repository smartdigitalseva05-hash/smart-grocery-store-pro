# Android app suite structure

```text
mobile/
├── README.md
├── APP_STRUCTURE.md
├── SECURITY_BASELINE.md
├── app-owner/
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── res/
├── app-shopkeeper/
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── res/
└── app-customer/
    └── src/main/
        ├── AndroidManifest.xml
        └── res/
```

## Role separation

- Owner app points only to the protected Owner portal. Database authorization and MFA are mandatory.
- Shopkeeper app points only to the shopkeeper workspace. It must not contain Owner routes or Owner navigation.
- Customer app points to the customer storefront. It must not expose shopkeeper or Owner dashboards.
- All three apps use the same production web origin but separate Android application IDs and app-specific branding.

## Shared technical requirements

- Android native shell with WebView for the existing responsive web workflows.
- HTTPS-only navigation with a strict same-origin/path allowlist.
- JavaScript and DOM storage only where required by the authenticated web application.
- No file/content access, no mixed content, no arbitrary JavaScript bridge, no cleartext traffic.
- Handle back navigation, network failures, loading state, app resume and session logout safely.
- Keep web workflows and database policy as the source of truth; never rely on a hidden button as authorization.

## Release tracks

- Internal/debug: developer testing only; not for customers.
- Internal Play testing: signed release build for invited testers.
- Production: Play App Signing, verified store listing, privacy policy, Data safety disclosures and completed acceptance tests.

The current Owner WebView APK is a separate legacy build workflow. Do not delete or overwrite it while this suite is being implemented.
