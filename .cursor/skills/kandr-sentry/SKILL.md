---
name: kandr-sentry
description: >-
  Kandr-wide Sentry conventions — org/project layout in Sentry, DSN handling per repo surface (web, admin, Functions, iOS), bootstrap checklist, and production issue triage (Issues, releases, tags). Use when adding or configuring Sentry, debugging production errors, triaging crashes alongside Crashlytics, onboarding a new app, or answering how many Sentry projects to create per client vs per codebase.
---

# Kandr Sentry

Standard playbook for [Sentry](https://sentry.io) across Kandr apps. Keeps DSNs out of git, aligns one repo’s surfaces with clear Sentry projects, and folds Sentry into debugging and bootstrap workflows.

---

## One org question — projects vs clients

**Do not create a separate Sentry project for every end customer / white-label client by default.**

| Approach | When to use |
|----------|-------------|
| **One Sentry project per deployable surface per Git repo** (recommended default) | Example for Faith Music–style repo: separate Sentry projects (or distinct DSNs) for **web**, **admin-console**, **Cloud Functions**, **iOS**. Same codebase: same mapping every time. |
| **Tags instead of extra projects** | Multi-tenant / white-label: add **`appId`**, **`tenant`**, or **`environment`** tags (and user/`tags` in SDK init) so Issues filter by customer **without** multiplying Sentry projects. |
| **Separate Sentry projects per client** | Only when a contract requires **data isolation**, separate quotas/billing, or client-specific access control in Sentry. |

**Summary:** Treat **one Git repo / product** as **one “product” in Sentry** with **multiple projects** (one per platform/runtime). Treat **clients** as **tags**, not new projects, unless isolation is required.

---

## Secrets and files — never commit keys

- The **DSN is public** (it only selects an ingest endpoint), but **still do not commit real `.env` values** — keep production DSNs in **CI secrets**, **Firebase Functions secrets**, or **local-only** `.env.local` (gitignored).
- **Auth tokens** for source maps (`SENTRY_AUTH_TOKEN`) and **build uploads** are **secrets** — CI-only, never in repo.
- Per-project reference: streaming-app uses `VITE_SENTRY_DSN`, Functions `SENTRY_DSN`, iOS scheme env `SENTRY_DSN` — match the pattern in each stack.

---

## Environment variables — what is tracked vs what you fill locally

**Tracked in Git (safe):** repo-root `web/.env.example`, `admin-console/.env.example`, `functions/.env.example` — **variable names only**, empty or placeholder values, plus comments. This is the canonical checklist for “which keys exist.”

**Never tracked:** real values — especially `SENTRY_AUTH_TOKEN` (`sntrys_…`). Put those in:

| Location | Purpose |
|----------|---------|
| **`web/.env.local`** | Local dev/build for Faith Music web — `VITE_*`, and for source-map upload also `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT` (read by Node when running `vite build`). |
| **`admin-console/.env.local`** | Same for admin SPA (use **admin** Sentry project slug for `SENTRY_PROJECT`). |
| **`functions/.env`** or emulator secrets | `SENTRY_DSN` for Functions emulator / local testing only if needed (gitignored). Production: Firebase **Secrets**. |
| **CI (GitHub Actions, etc.)** | Same keys as encrypted secrets; inject into `env:` for build/deploy jobs. |
| **Xcode scheme** | iOS: `SENTRY_DSN`, optional `SENTRY_ENVIRONMENT` — not in repo. |

### Canonical names (copy into `.env.local` yourself)

**Web / admin (Vite runtime — exposed to bundle only if prefixed `VITE_`):**

| Variable | Required | Notes |
|----------|----------|--------|
| `VITE_SENTRY_DSN` | No | Empty = browser SDK disabled. |
| `VITE_APP_VERSION` | No | Release label in Sentry (CI/git SHA). |

**Web / admin (build-time — Node only, used by `vite.config` + `@sentry/vite-plugin`):**

| Variable | Required for upload | Notes |
|----------|---------------------|--------|
| `SENTRY_AUTH_TOKEN` | Yes for uploads | **Secret.** Never commit. Create in Sentry → Settings → Auth Tokens (Org-scoped with `project:releases` / releases scope). |
| `SENTRY_ORG` | Yes | Org slug (e.g. `kandr`). |
| `SENTRY_PROJECT` | Yes | **Per build:** web uses the web project slug; admin uses the **admin** project slug (different from web). |

**Cloud Functions:**

| Variable | Notes |
|----------|--------|
| `SENTRY_DSN` | Bind via `firebase functions:secrets:set SENTRY_DSN` for production. |

**iOS (scheme / xcconfig, not `.env`):**

| Variable | Notes |
|----------|--------|
| `SENTRY_DSN` | Required to enable Cocoa SDK. |
| `SENTRY_ENVIRONMENT` | Optional override (`development` / `production`). |

### One-liner local build with uploads (after filling `.env.local`)

From `web/` or `admin-console/`:

```bash
npm run build
```

Vite loads `.env`, `.env.local`, `.env.[mode].local` automatically — keep secrets in **`.env.local`**.

### Firebase Functions — never duplicate `SENTRY_DSN`

Do **not** put `SENTRY_DSN` in **`functions/.env`** while using **`setGlobalOptions({ secrets: ["SENTRY_DSN"] })`**. Firebase merges `.env` as **plain** runtime env vars; GCP then rejects deploy: *Secret environment variable overlaps non secret env*. Use **Secret Manager only** for production; for emulator, **`export SENTRY_DSN=...`** in the shell before `emulators:start`.

---

## Per-surface checklist (existing repo)

Use when wiring or verifying Sentry:

| Surface | SDK | Env / config | Notes |
|---------|-----|----------------|-------|
| **Vite web** | `@sentry/react` | `VITE_SENTRY_DSN`, optional `VITE_APP_VERSION` | `instrument.ts` must be **first** import in `main.tsx`; React 19 → `reactErrorHandler` on `createRoot`. Optional `@sentry/vite-plugin` when `SENTRY_AUTH_TOKEN` + `SENTRY_ORG` + `SENTRY_PROJECT` set at build. |
| **Admin (Vite)** | `@sentry/react` | Same pattern | Separate Sentry **project** + DSN from public web. |
| **Cloud Functions** | `@sentry/node` | `SENTRY_DSN` in runtime | Init in a file imported **before** `firebase-init`. Bind DSN via Firebase **Secrets** + `setGlobalOptions({ secrets: ["SENTRY_DSN"] })` when ready so all Gen2 functions receive it. |
| **iOS** | `sentry-cocoa` (SPM) | `SENTRY_DSN`, optional `SENTRY_ENVIRONMENT` | Start SDK only when DSN non-empty. Can coexist with **Firebase Crashlytics** — use Sentry for unified web/backend correlation + optional Session Replay / tracing; Crashlytics remains fine for Apple-native crash workflows. |

---

## New project bootstrap (with `project-bootstrap` skill)

When Phase 1 includes monitoring:

1. In Sentry: create **organization** (or reuse Kandr org) and **one project per platform** you ship (e.g. `{codename}-web`, `{codename}-admin`, `{codename}-functions`, `{codename}-ios`).
2. Copy DSNs into the right env templates (never commit production values).
3. Add the **same** `instrument.ts` / `sentry-init.ts` / Swift init patterns as Faith Music streaming-app once code exists.
4. For CI: store `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT` per web/admin project if using source map upload.

Cross-reference: **`project-bootstrap`** Phase **2.12 Sentry** (checklist).

---

## Triage and debugging — when to use this skill

Whenever investigating **production** or **TestFlight** issues, **intermittent** failures, or **regressions** after deploy:

1. **Sentry → Issues** — filter by `release`, `environment`, `user`, and custom **tags** (`appId`, route, function name).
2. **Performance / traces** (if enabled) — correlate slow transactions with deploy time.
3. **Replays** (web) — if enabled, inspect sessions around errors.
4. **Releases** — confirm the **release** string matches your deploy (web: `VITE_APP_VERSION`; iOS: version+build; Functions: revision env if set).
5. **Firebase** — logs, Crashlytics (iOS), Analytics for overlap.
6. **Regression workflow** — follow the `kandr-qa` skill's production triage loop when the issue is not reproducible locally. Its evidence-first rule applies here: do not report an error rate or a fix as confirmed without live Sentry output.

If Sentry is **empty** for a reported bug: verify DSN env is set for that surface, sampling is not zero, and the issue isn’t device-only without SDK init.

---

## Per-app setup runbooks

Setup order, secret names, and build-tool wiring differ per app and live in that repo:

| App | Skill |
|---|---|
| Faith Music (`streaming-app`) | `.cursor/skills/faith-music-sentry/` |
| Kandr Radio (`radio-app`) | `.cursor/skills/radio-sentry/` — multi-station, uses the `SENTRY_DSN_BODY` xcconfig pattern |

When onboarding a new app, follow the bootstrap section above and add its runbook to its own
repo rather than to this skill.

---

## Quick links

- [Client Keys (DSN)](https://sentry.io/settings/projects/)
- [Auth tokens (upload / API)](https://sentry.io/settings/account/api/auth-tokens/)
- Official router for SDK docs: `sentry-sdk-setup` skill in Cursor Sentry plugin, or [docs.sentry.io](https://docs.sentry.io)
