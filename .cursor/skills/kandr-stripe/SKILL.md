---
name: kandr-stripe
description: Stripe across Kandr apps — the API version, which account a key belongs to and where it may be stored, resolving the Kandr secret from Secret Manager, per-project setup, and the Cloud Functions, React, and webhook implementation patterns. Use when working on checkout, subscriptions, billing, invoices, payment links, the customer portal, a Stripe webhook, or when deciding where a Stripe key belongs.
---

# Stripe

Stripe is used for payments across multiple Kandr apps. All apps use API version
`2024-12-18.acacia`.

## Kandr's account vs a client's account

This distinction governs everything below. Get it wrong and you put someone else's payment
credentials somewhere they must never be.

**Kandr's business account is `acct_1BkgZwYzUC9pmt72JzDX`.** Its `sk_live` key is the only Stripe
key that belongs in GCP Secret Manager, stored as `STRIPE_SECRET_KEY` on `streamingapp-32dcb`,
`kandr-radio-app`, and `sunny-slope-haus-kandr` (verified same account).

**Client keys are never stored centrally.** A radio station, a restaurant, or any other customer
enters their own Stripe key, and it lives in that tenant's application config — for the radio app,
`stripeSecretKey` on the station's Firestore document, edited through the admin console and masked
in the UI. A client key must never be written to Secret Manager, a `.kandr-secrets` manifest, a
rule, or a skill.

Before storing any Stripe key, confirm whose it is:

```bash
curl -s https://api.stripe.com/v1/account -u "$KEY:" | jq -r .id
```

If it is not `acct_1BkgZwYzUC9pmt72JzDX`, it is a client's — route it to per-tenant storage.

## Default Stripe account (MCP, scripts, Kandr billing)

- **Use for:** Stripe MCP (after auth), local/one-off scripts, Payment Links, invoicing, customer
  setup, and any "bill this client" work billed *by Kandr*.
- **Prefer resolving from:** `streamingapp-32dcb` first, then `kandr-radio-app`.
- **Do not rely on:** `hunter-book-club-kandr` (often no secret) or `rlibbey-pocs` (currently a
  placeholder — `createInvoice` on kandr.io fails until it is filled).
- **`pizzeria-pfiff-kandr`** holds the literal string `disabled`, an intentional kill switch. Do
  not "fix" it.

```bash
export STRIPE_SECRET_KEY="$(gcloud secrets versions access latest --secret=STRIPE_SECRET_KEY --project=streamingapp-32dcb)"
```

Optional override: set `STRIPE_SECRET_GCP_PROJECT=kandr-radio-app` to read deliberately from the
other project (same key today).

Never commit keys; only project id + secret name belong in rules/skills.

## Projects Using Stripe

### Faith Music Streaming (`streamingapp-32dcb`)
- **Secrets**: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` in GCP Secret Manager
- **Publishable Key**: in `web/.env` and `admin-console/.env` as `VITE_STRIPE_PUBLISHABLE_KEY`
- **Features**: B2C subscriptions (embedded + redirect checkout), customer portal, bulk
  subscriptions, platform billing, revenue import for royalties
- **Client SDK**: `@stripe/stripe-js`, `@stripe/react-stripe-js` (web + admin)
- **Server**: `stripe` npm package in Cloud Functions

### Kandid Restoration (`photo-restorer-new v2`)
- **Features**: Subscription checkout, customer portal, webhook handler
- **Server**: Express API on Cloud Run (`api/create-checkout-session.js`, `api/webhook.js`)

## Implementation Pattern

### Cloud Functions (Firebase)
```typescript
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2024-12-18.acacia",
});
```

Secrets are declared in function config:
```typescript
export const myFunction = onCall(
  { secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => { /* ... */ }
);
```

### Client-Side (React)
```typescript
import { loadStripe } from "@stripe/stripe-js";
import { EmbeddedCheckoutProvider, EmbeddedCheckout } from "@stripe/react-stripe-js";

const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY);
```

### Webhook Handling
- Verify signature with `STRIPE_WEBHOOK_SECRET` — this is a **separate** secret from
  `STRIPE_SECRET_KEY` in the same GCP project; do not confuse them
- Use `stripe.webhooks.constructEvent(body, sig, secret)`
- Handle events: `checkout.session.completed`, `customer.subscription.updated`,
  `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
- Follow the idempotency and error-return order in the `kandr-functions` skill — process first,
  write the idempotency record only after success, return 500 (not 200) on failure so Stripe
  retries

## MCP Tools

The Stripe MCP server is available for querying Stripe data directly (customers, subscriptions,
invoices, etc.). Use `CallMcpTool` with `server: "plugin-stripe-stripe"`.

Authenticate `plugin-stripe-stripe` so MCP tools run against the Stripe Dashboard account matching
the secret above — the main Kandr live account.
