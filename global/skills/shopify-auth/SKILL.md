---
name: shopify-auth
description: Shopify embedded app authentication patterns including session token verification, OAuth token exchange, and traditional OAuth redirect flow. Use when building Shopify app auth, debugging 401/500 errors on Shopify API calls, setting up token exchange, configuring OAuth redirect URLs, or working with Shopify session tokens.
---

# Shopify Embedded App Authentication

## Two Auth Paths

Shopify embedded apps have two ways to obtain an offline access token for Admin API calls:

1. **Token Exchange** (primary, modern) — converts a session token into an offline access token server-side. No redirects.
2. **OAuth Redirect** (fallback, legacy) — traditional redirect to Shopify consent screen, callback with authorization code.

Both paths produce the same result: an offline access token stored server-side for making Shopify Admin API calls.

## Session Token Verification

Session tokens from App Bridge are JWTs signed with **HMAC-SHA256 using the app's client secret** (NOT RSA/JWKS).

```typescript
import { jwtVerify } from "jose";

const key = new TextEncoder().encode(process.env.SHOPIFY_API_SECRET);
const { payload } = await jwtVerify(token, key, {
  audience: process.env.SHOPIFY_API_KEY,
});

// Validate iss claim (required by Shopify security spec)
const shopDomain = payload.dest?.replace("https://", "");
const expectedIss = `https://${shopDomain}/admin`;
if (payload.iss !== expectedIss) throw new Error("iss mismatch");
```

**Critical**: Do NOT use `createRemoteJWKSet` or fetch from `cdn.shopify.com/services/partner/keys.json` — that URL does not exist. Shopify session tokens are symmetric (HMAC), not asymmetric (RSA).

## Token Exchange

Exchanges a session token (from App Bridge) for an offline access token. No user interaction required.

### TOML Prerequisites

```toml
[access_scopes]
scopes = "read_locations,write_locations"
use_legacy_install_flow = false

[build]
include_config_on_deploy = true
```

- `use_legacy_install_flow = false` — **required** to enable token exchange
- `include_config_on_deploy = true` — **required** for `shopify app deploy` to push config to Shopify

After changing TOML, always run `npx shopify app deploy` to push to Shopify.

### Token Exchange Request

```typescript
const response = await fetch(
  `https://${shopDomain}/admin/oauth/access_token`,
  {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({
      client_id: SHOPIFY_API_KEY,
      client_secret: SHOPIFY_API_SECRET,
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: sessionToken,
      subject_token_type: "urn:ietf:params:oauth:token-type:id_token",
      requested_token_type:
        "urn:shopify:params:oauth:token-type:offline-access-token",
    }),
  }
);
const { access_token } = await response.json();
```

### Critical Parameters

| Parameter | Correct Value | Common Mistake |
|-----------|--------------|----------------|
| `Content-Type` | `application/x-www-form-urlencoded` | `application/json` (rejected) |
| `subject_token_type` | `...token-type:id_token` (underscore) | `...token-type:id-token` (hyphen — causes `invalid_subject_token_type`) |
| Body encoding | `new URLSearchParams({...})` | `JSON.stringify({...})` (wrong format) |

### Token Exchange Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `invalid_subject_token_type` | Hyphen instead of underscore in `id_token`, or wrong Content-Type | Fix the URN string and use form-urlencoded |
| `invalid_subject_token` | Expired or malformed session token | Get a fresh token from `app.idToken()` |
| Token exchange not supported | `use_legacy_install_flow` is still `true` or not deployed | Set to `false` in TOML, run `shopify app deploy` |
| Token exchange fails for existing installs | App was installed before managed flow was enabled | Uninstall and reinstall the app, or use OAuth fallback |

## OAuth Redirect Flow (Fallback)

For legacy installs or when token exchange is unavailable.

### Redirect URLs

Must be whitelisted in the TOML and deployed:

```toml
[auth]
redirect_urls = [
  "https://your-production-url.com/auth/callback",
  "https://your-cloud-function-url.run.app/auth/callback"
]
```

The `include_config_on_deploy = true` setting is required for these URLs to actually reach Shopify when you run `shopify app deploy`. Without it, the URLs stay local only.

### OAuth Flow

1. **Begin**: Redirect merchant to `https://{shop}/admin/oauth/authorize?client_id=...&scope=...&redirect_uri=...&state={nonce}`
2. **Callback**: Shopify redirects back with `?code=...&hmac=...&shop=...&state=...`
3. **Validate**: Check HMAC with `timingSafeEqual`, verify nonce
4. **Exchange code**: POST to `https://{shop}/admin/oauth/access_token` with `client_id`, `client_secret`, `code`
5. **Store**: Encrypt token (Cloud KMS recommended), save to Firestore

### HMAC Validation

OAuth callback HMAC uses the query string (excluding `hmac` param), sorted alphabetically:

```typescript
import { createHmac, timingSafeEqual } from "crypto";

const { hmac, ...params } = query;
const sorted = Object.keys(params).sort()
  .map(k => `${k}=${params[k]}`).join("&");
const computed = createHmac("sha256", secret).update(sorted).digest("hex");
return timingSafeEqual(Buffer.from(hmac), Buffer.from(computed));
```

## Recommended Architecture

```
Frontend (App Bridge)
  │
  │  session token (JWT, HMAC-SHA256)
  ▼
Backend Middleware (verify session token)
  │
  │  check Firestore for stored access token
  ▼
Token exists? ──yes──▶ Decrypt via KMS → use for Admin API
  │
  no
  │
  ▼
Token Exchange (session token → offline access token)
  │
  ▼
Encrypt via KMS → store in Firestore → use for Admin API
```

The backend auto-provisions merchants on first API call via token exchange. No separate install/onboarding step needed.

## Cloud KMS Setup

Encrypt access tokens at rest using GCP Cloud KMS:

```bash
# Create key ring and key
gcloud kms keyrings create waypoint --location=us-central1 --project=PROJECT_ID
gcloud kms keys create shopify-tokens --keyring=waypoint \
  --location=us-central1 --purpose=encryption --project=PROJECT_ID

# Grant permission to Cloud Function service account
# IMPORTANT: Check which SA the function uses first:
gcloud functions describe FUNCTION_NAME --region=us-central1 \
  --format="value(serviceConfig.serviceAccountEmail)" --project=PROJECT_ID

# Then grant to THAT service account (often the Compute Engine default SA)
gcloud kms keys add-iam-policy-binding shopify-tokens \
  --keyring=waypoint --location=us-central1 --project=PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
```

**Pitfall**: 2nd gen Cloud Functions use the Compute Engine default SA (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`), NOT the App Engine SA (`PROJECT_ID@appspot.gserviceaccount.com`). Always verify with `gcloud functions describe`.

## Firebase Cloud Functions Setup

Each function entry point that uses Firestore needs `initializeApp()`:

```typescript
import { initializeApp, getApps } from "firebase-admin/app";
if (getApps().length === 0) initializeApp();
```

The `SHOPIFY_API_SECRET` must be available via Secret Manager:

```typescript
import { defineSecret } from "firebase-functions/params";
const shopifyApiSecret = defineSecret("SHOPIFY_API_SECRET");

export const api = onRequest({
  invoker: "public",
  secrets: [shopifyApiSecret],
}, app);
```

**Do NOT** put `SHOPIFY_API_SECRET` in `functions/.env` when also using `defineSecret` — Firebase rejects overlapping secret and env var names.

## Frontend Session Token Setup

Set the token provider synchronously (not in `useEffect`) to avoid race conditions:

```typescript
import { useAppBridge } from "@shopify/app-bridge-react";
import { useRef } from "react";

export function useShopifyAuth() {
  const app = useAppBridge();
  const initialized = useRef(false);
  if (!initialized.current) {
    setSessionTokenProvider(() => app.idToken());
    initialized.current = true;
  }
}
```

**Pitfall**: If `setSessionTokenProvider` is called inside `useEffect`, child components' effects fire first and API calls fail with "Session token provider not configured."

## Checklist for New Shopify App Auth

- [ ] TOML has `use_legacy_install_flow = false`
- [ ] TOML has `include_config_on_deploy = true`
- [ ] TOML `redirect_urls` includes all callback URLs (production + Cloud Function)
- [ ] Ran `npx shopify app deploy` after TOML changes
- [ ] Session token verified with HMAC-SHA256 (NOT JWKS)
- [ ] `iss` claim validated against `https://{shop}/admin`
- [ ] Token exchange uses `application/x-www-form-urlencoded` + `URLSearchParams`
- [ ] Token exchange uses `id_token` (underscore, NOT hyphen)
- [ ] `SHOPIFY_API_SECRET` in GCP Secret Manager (not in `functions/.env`)
- [ ] KMS key created and IAM granted to the correct service account
- [ ] `initializeApp()` called in every function entry point
- [ ] `invoker: "public"` on all `onRequest` functions
- [ ] Frontend sets session token provider synchronously (not in useEffect)
