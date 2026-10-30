# Database Change Log

These migrations have already been applied to the Supabase production project.

| Migration version | Migration | Change |
|---|---|---|
| Edge Function v3 | razorpay-subscription-checkout | Adds compare-and-set persistence for Razorpay order IDs so concurrent checkout requests reuse one stored order instead of overwriting each other. |
| 20261030122353 | restrict_order_cancellation_to_unpaid_cod | Cancellation is limited to pending, unpaid COD orders; stock is restored transactionally. |
| 20261030122741 | restrict_direct_order_updates | Removes direct client UPDATE access to orders; order changes use guarded database RPCs. |
| 20261030122819 | restrict_payment_creation_to_trusted_rpc | Removes direct client INSERT access to payment records; trusted checkout RPC creates payment rows. |
| 20261030122847 | serialize_product_plan_limit_checks | Serializes product creation/moves per shop to prevent concurrent requests exceeding product limits. |
| 20261030122920 | serialize_monthly_order_limit_checks | Locks the shop during order placement, validates active status and subscription expiry, and serializes monthly order-limit checks/counter updates. |
| 20261030122952 | preserve_customer_historical_product_visibility | Lets a customer read product details for products in their own order history, even if the shop later becomes inactive. |
| 20261030123021 | deduplicate_order_cancellation_history | Uses the order-status trigger as the single history writer and carries the cancellation reason into history/audit records. |

## Verification notes

- Migration `20261030130935_disable_additional_super_admin_accounts` is applied and source-controlled. The existing Owner remains the only Super Admin; attempts to promote another profile to Super Admin are rejected by the database trigger. This prevents additional admin accounts from gaining the Owner-only control surface.

- Rollback-only database smoke tests passed for profile RLS, role-escalation prevention, last-Super-Admin protection, shop application approval, inactive shop application creation, activation bypass rejection, synthetic subscription payment activation, product limit cap, monthly order cap, COD delivery progression, cancellation stock restoration/history, and hourly expiry deactivation. All temporary rows and plan changes were rolled back.
- Latest Security Advisor result: one warning remains for leaked-password protection. Supabase documents this control as available on Pro Plan and above; no plan upgrade was made.
- Latest Performance Advisor result: 14 informational unused-index notices remain. Indexes were retained because the project has no real workload data yet.

- Migration `20261030125950_grant_minimal_payment_access_to_edge_service_role` adds only the read and update column permissions required by the payment Edge Functions; it does not permit creating or deleting payment records.

- Migration `20261030125729_close_direct_superadmin_shop_activation_bypass` is applied and source-controlled. Direct Super Admin table updates can no longer activate shops or alter subscription plan/expiry fields; the protected Owner status RPC rechecks a verified active subscription, and the expiry job can only deactivate shops.

- `shopkeeper.html` keeps the subscription button disabled while Razorpay Checkout is open, preventing accidental multiple checkout modals for the same pending payment.
- `apply-shop.html` now provides a Resend confirmation email action for accounts blocked by email confirmation.
- GitHub Actions checks the approved `index.html` blob SHA and stops deployment if that file changes unexpectedly.

- Migration `20261030124909_serialize_order_cancellation_stock_restoration` is applied and source-controlled. Cancellation now locks the shop before restoring product stock, matching order-placement lock order and reducing deadlock risk during concurrent orders/cancellations.

- Migration `20261030124558_require_explicit_subscription_billing_cycle` is applied. The checkout RPC now rejects a missing billing cycle instead of accidentally falling through to yearly pricing. The `shop_subscriptions.billing_cycle` column is also now NOT NULL; the existing monthly/yearly check constraint remains in place.
- All three Razorpay Edge Functions now use Supabase's `@supabase/server` authentication wrapper. User-facing functions use the authenticated-user context; the Razorpay webhook uses signature verification and the server-side admin client. Checkout and verification explicitly handle browser CORS preflight before auth middleware.

- Migration `20261030123909_merge_product_historical_read_policy` is applied and source-controlled. It merges active-shop product visibility and a customer's own historical-order product visibility into one SELECT policy; the multiple-permissive-policy performance warning is cleared.

- Migration `20261030123652_guard_subscription_activation_state` is applied and source-controlled. It checks that the shopkeeper account remains approved and active, the shop is not suspended, the subscription is pending and linked to the payment, and the captured amount matches its billing cycle before activating a shop.
- Razorpay Edge Function source files are tracked under `supabase/functions/`. Checkout function v7 and verification function v4 use Supabase's server auth wrapper and strict request validation; checkout v6 prevents concurrent calls from overwriting the stored Razorpay order reference. Webhook v3 uses the server-side admin client after signature validation and rejects malformed JSON.

- All 14 public tables have Row Level Security enabled.
- Direct order UPDATE and direct payment INSERT policies are absent.
- The product-limit and order-limit functions were re-read after migration.
- The cancellation function and order-status audit trigger were re-read after migration.
- Supabase Security Advisor currently reports one warning: leaked-password protection is disabled. Enable it in Supabase Auth password-security settings if available on the project plan.
- End-to-end customer/shopkeeper/payment workflows still require test accounts, at least one approved shop, and Razorpay test credentials. Do not treat the application as production-verified until those flows pass.

This file documents applied database changes; it is not a replacement for the Supabase migration SQL files.
