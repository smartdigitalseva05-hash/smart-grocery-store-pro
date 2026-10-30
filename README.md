# Smart Grocery Store Pro

Multi-vendor grocery ordering platform with customer ordering, shopkeeper workspaces, Owner controls, subscriptions and order tracking.

## Workspaces
- portal.html — platform portal and live subscription pricing.
- apply-shop.html — customer signup/login and shop application submission.
- index.html — customer grocery storefront.
- my-orders.html — customer order history and pending-order cancellation.
- shopkeeper.html — shopkeeper products, stock, subscriptions and incoming orders.
- owner.html — Owner dashboard, shop status and payment review.

## Subscription pricing
| Plan | Monthly | Annual |
|---|---:|---:|
| Basic | ₹99 | ₹990 |
| Pro | ₹199 | ₹1,990 |
| Enterprise | ₹299 | ₹2,990 |

Annual prices are 10 months of the monthly price. Pricing is read from the Supabase subscription_plans table.

## Backend
Supabase project: wqlopfftzvsjsxmrmxeq.
The frontend uses a publishable key only. Authorization and tenant isolation must be enforced by database RLS and validated RPCs; never put service-role/secret keys in browser code.

## Important launch status
- Payment gateway checkout/webhook is not deployed yet; pending payment records do not collect money.
- GitHub source files have been committed and JavaScript syntax-checked. Public website deployment and full end-to-end testing must still be confirmed.
- Existing index.html is intentionally preserved.
