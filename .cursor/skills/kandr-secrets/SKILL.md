---
name: kandr-secrets
description: How Kandr projects resolve API keys, tokens, and passwords from GCP Secret Manager. Read this before adding a secret, wiring a credential into code, writing an env file, or when a command fails on a missing key.
---

# Kandr secrets

**GCP Secret Manager is the only source of truth.** A credential value never appears in a tracked file — not in a rule, not in a skill, not in a script, not in a README. What gets committed is the *name* of the secret and the *project* that holds it.

The `gcloud` CLI is already authenticated as `rlibbey@gmail.com`, so reading a secret needs no login, no prompt, and no manual key entry. That is the whole point: referencing a secret must be cheaper than pasting one.

## The manifest

Every repo that needs secrets has a `.kandr-secrets` file at its root, committed to git. It maps local env var names to the project holding them:

```
# Faith Music Streaming
STRIPE_SECRET_KEY=streamingapp-32dcb
STRIPE_WEBHOOK_SECRET=streamingapp-32dcb
AGENTMAIL_API_KEY=streamingapp-32dcb
MATCH_PASSWORD=streamingapp-32dcb

# renamed: local var on the left, remote secret name on the right
AWS_ACCESS_KEY_ID=streamingapp-32dcb:aws-access-key
```

The `PROJECT:REMOTE_NAME` form exists because a few older secrets do not follow the naming convention, and because Vite needs a `VITE_` prefix that the cloud secret does not carry.

This file is safe to commit. It contains no values.

## The helper

`kandr-secrets` is installed on PATH (`~/.cursor/scripts/kandr-secrets.sh`). It finds the manifest by walking up from the current directory, so it works from any subdirectory.

| Command | Use it for |
|---|---|
| `eval "$(kandr-secrets load)"` | Export every secret into the current shell before running a script |
| `kandr-secrets env .env.local` | Generate a gitignored env file for Vite, Fastlane, or a local server |
| `kandr-secrets get NAME` | Pipe one value into a single command |
| `kandr-secrets doctor` | Verify every entry resolves — run this first when a credential-related command fails |
| `kandr-secrets list` | Show what the repo expects and where each secret lives |

Add `--group NAME` to limit a command to one manifest section, so a Fastlane env file does not receive a Sentry token.

Values are cached under `~/.cache/kandr-secrets` for 15 minutes at `0600`, which takes a repeat load from ~700ms to ~40ms. Pass `--no-cache` after rotating a secret, or run `kandr-secrets clear-cache`.

`kandr-secrets env` refuses to write to a path git would track. If it errors, add the path to `.gitignore` rather than working around it. Multi-line values such as PEM private keys are written double-quoted with escaped newlines, which both Ruby and Node dotenv expand correctly — do not hand-edit them back into raw multi-line form.

## Choosing a consumption path

Match the mechanism to where the code runs. Do not generate an env file for something that can bind at runtime.

**Cloud Functions — bind, never fetch.** Firebase injects the secret at runtime. Nothing is needed locally and nothing is written to disk.

```typescript
export const chargeCustomer = onCall(
  { secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => { /* process.env.STRIPE_SECRET_KEY is populated */ }
);
```

The secret must exist on the *same* project the functions deploy to. Cross-project reads need an explicit IAM grant and are a smell — copy the secret instead.

**Fastlane — generate `.env`.** Fastlane auto-loads `fastlane/.env`, so `MATCH_PASSWORD` and Apple credentials resolve without a prompt:

```bash
kandr-secrets env ios/fastlane/.env --group fastlane
```

Use exactly that filename. Fastlane's dotenv helper loads only `.env` and `.env.default`; a `.env.local` is read solely when a lane runs with `--env local`, so secrets written there are ignored with no error at all. And `.env.default` is not gitignored in any Kandr repo, so it must never hold a secret.

**Vite / client apps — generate `.env.local`.** Only ever publishable values. A `VITE_`-prefixed variable ships to the browser, so a secret key must never carry that prefix.

**One-off scripts — load into the shell.**

```bash
eval "$(kandr-secrets load)"
node scripts/backfill.mjs
```

## Adding a new secret

1. Create it on the project that consumes it, using a `SCREAMING_SNAKE_CASE` name:

```bash
printf '%s' "$VALUE" | gcloud secrets create MY_TOKEN \
  --project=PROJECT_ID --replication-policy=automatic --data-file=-
```

2. Add a line to `.kandr-secrets`.
3. Add the name (never the value) to the project's `kandr-overlay.mdc` secrets table.
4. Run `kandr-secrets doctor` to confirm it resolves.

Use `printf '%s'` rather than `echo`. A trailing newline in a secret produces failures that look nothing like their cause — Fastlane Match in particular reports a wrong-password error for a value that is correct apart from the newline.

## Kandr credentials vs client credentials

Secret Manager holds **Kandr's own** credentials only. A client's credentials — a radio station's Stripe key, a customer's API token — are theirs, are entered by them, and belong in **per-tenant application storage**, never in Secret Manager, a manifest, a rule, or a skill.

The radio app is the reference implementation: each station's `stripeSecretKey` lives in that station's Firestore config, is edited through the admin console, and is masked in the UI. Functions read it per request. Nothing about it is global.

| | Kandr credential | Client credential |
|---|---|---|
| Lives in | GCP Secret Manager | Per-tenant Firestore/app config |
| Named in | `.kandr-secrets` manifest | Nowhere in the repo |
| Scope | One per project | One per tenant |

Kandr's Stripe account is `acct_1BkgZwYzUC9pmt72JzDX`. If a Stripe key resolves to a different account, it belongs to a client and must not be stored as `STRIPE_SECRET_KEY` in Secret Manager. Verify with `curl -s https://api.stripe.com/v1/account -u "$KEY:"` before storing any Stripe key.

## Rules

- Never write a credential value into a tracked file, a commit message, a log line, or chat.
- Never print a secret to verify it. Compare lengths or hashes instead.
- A secret shared by several projects exists as a separate copy per project. Rotating it means updating every copy — check `agentmail.mdc` for which projects share which key before rotating.
- When a value in Secret Manager reads `placeholder`, `PLACEHOLDER`, or `CHANGE_ME`, treat it as missing. It is worse than absent, because a non-empty string passes an `if (!key)` guard and fails later at the API call.
- If a secret genuinely does not exist yet, say so and ask. Do not invent a value, and do not silently fall back to a key from another project.
