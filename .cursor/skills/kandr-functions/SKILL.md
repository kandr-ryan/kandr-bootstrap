---
name: kandr-functions
description: Cloud Functions conventions for every Kandr project — naming, the check-before-you-export gate, callable backward compatibility, structured logging, webhook idempotency, and secret handling. Use when creating, editing, reviewing, or debugging a Cloud Function, an HTTP endpoint, a Firestore trigger, a scheduled job, or a webhook handler.
---

# Cloud Functions

Baseline across all projects: **Node 22, TypeScript, Firebase Functions**.
Region, project ID, secret names, and the local function catalog live in that repo's
`kandr-overlay.mdc` or `project-context.mdc`.

---

## 1. Check before you export

Function catalogs grow into swamps. Before adding any new export:

1. **Search the existing functions** in the same domain. Larger projects keep a catalog skill
   listing every deployed function — read it first.
2. **Prefer extending** an existing function over adding a near-duplicate.
3. **Confirm with the user** before writing a genuinely new export.
4. **Verify `functions/src/index.ts`** actually exports it — a function that exists but is not
   exported is not deployed, and this failure is silent.
5. **Update the catalog** after the function ships, if the project keeps one.

A codebase with `sendWelcomeEmail`, `sendWelcomeEmailV2`, and `sendUserWelcome` is the
outcome this rule prevents.

---

## 2. Naming

| Kind | Pattern | Example |
|---|---|---|
| Firestore / Auth trigger | `onX` | `onUserCreated`, `onOrderWritten` |
| Webhook handler | `handleX` | `handleStripeWebhook` |
| Callable | `verbNoun` | `createCheckoutSession`, `syncSubscription` |
| Scheduled job | `scheduledX` | `scheduledNightlyReport` |

Use the same name in the catalog, the source file, and the `index.ts` export.

---

## 3. Callable contracts are permanent

Shipped clients call functions by name and send the payload they were built with. They do not
update when you do.

- **Never rename or remove** a callable export while any shipped client may still call it
- **Never add a required request parameter** — old clients will not send it
- **Never remove a response field** a client reads
- Adding optional parameters and new response fields is always safe
- To change a signature: version the new function alongside the old, keep the old as a thin
  wrapper, and deprecate on a schedule once client telemetry supports it

---

## 4. Structured logging

Every `catch` block logs with context. Silent failures in a background trigger are invisible
until a user complains weeks later.

```ts
} catch (error) {
  logger.error("createCheckoutSession failed", {
    error,
    userId,
    // whatever identifiers make this traceable
  });
  throw new HttpsError("internal", "Something went wrong. Please try again.");
}
```

- `logger.error` in every catch, with identifiers that make the entry traceable
- `logger.info` on successful batch or scheduled work, with counts
- Never log tokens, keys, full auth headers, or payment credentials
- Error messages returned to clients are user-safe; the diagnostic detail goes to the log

---

## 5. Webhooks

Order matters. This sequence is what keeps duplicate deliveries from double-charging users:

1. **Verify the signature** against the webhook secret. Reject unverified requests.
2. **Validate the payload** — required metadata present, IDs well-formed.
3. **Check idempotency** — has this event ID already been processed?
4. **Process** the event.
5. **Write the idempotency record only after processing succeeds.** Writing it first means a
   mid-processing crash permanently marks the event done and the work never happens.
6. **Return 500 on failure, not 200.** Providers retry on 5xx. Returning 200 on an error
   silently discards the event.

Convert provider epoch timestamps through a null-safe helper — a missing or zero timestamp
turned into a `Date` is a classic source of corrupt records.

---

## 6. Secrets

- Declare secrets in the function config: `secrets: ["STRIPE_SECRET_KEY"]`
- Read them from `process.env` at call time, never at module load
- Store them in GCP Secret Manager, per project — Secret Manager is not global to the account
- **Never** write a secret to a client-readable data path. Server-only config paths only
- Never commit a secret. Never paste one into a rule, skill, or changelog

---

## 7. Data access

- Client writes to sensitive collections (orders, subscriptions, entitlements, audit records)
  go through callables, never direct client writes
- Validate the caller's identity and tenant scope on every callable — never trust a
  client-supplied tenant/org/app ID without checking it against the auth token
- Multi-tenant projects scope every read and write by the tenant key; never hardcode a
  single tenant ID in shared code

---

## 8. Before deploying

Run `npx tsc --noEmit` in the functions package. Then follow `kandr-deploy`.

---

## Related skills

- `kandr-development` — the backward-compatibility gate for contract changes
- `kandr-qa` — the regression gate before deploying
- `kandr-deploy` — deploy commands and authority
