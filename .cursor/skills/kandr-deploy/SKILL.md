---
name: kandr-deploy
description: Deployment authority and workflow for every Kandr project — what the agent may deploy without asking, what requires explicit permission, the path-to-target deploy table, and the verification evidence required before reporting something as shipped. Use when finishing a change that only takes effect after deploy, when the user says deploy or ship or push it live, or when deciding whether a deploy needs permission.
---

# Deploy

Project IDs, hosting targets, and the path→target table live in that repo's
`kandr-overlay.mdc`. This skill is the authority model and the workflow.

---

## 1. What the agent may deploy

**Backend and web: yes, without asking.**

When a change only takes effect in production after a deploy — hosting assets, admin console
UI, security rules, indexes, Cloud Functions — run the deploy in the same session once the
build passes. Do not stop and wait for a separate "please deploy" message. Leaving finished
work sitting on disk is not finishing.

Exceptions: the user said not to deploy, or the change is intentionally local-only.

**Native app builds: no, never without explicit permission.**

Never run `fastlane beta`, `deliver`, `xcodebuild archive`, or an Android release upload
unless the user asked for it in explicit terms. "Fix this bug" is not a request to ship a
build to TestFlight. Code changes to native app source do not imply a build.

**Destructive credential operations: no, ever.**

No `match nuke`, no revoking or deleting certificates, no deleting keychain identities,
no rotating credentials — regardless of what would be convenient. If signing is broken,
describe the error and ask. See `local-toolchain.mdc`.

This skill grants permission to *execute* a deploy. It does not grant permission to skip
the review gates in `kandr-development` and `kandr-qa`.

---

## 2. Before deploying

1. Typecheck the touched packages: `npx tsc --noEmit`
2. Build, if the project has a build step
3. Run the regression gate if the change touched functions, data models, or native code
   (see `kandr-qa`)
4. Only then deploy

Deploying code that does not compile wastes a rollback cycle and can take a surface down.

---

## 3. The path-to-target table

Every project defines one in its overlay, mapping changed paths to deploy commands:

```markdown
| Changed paths | Deploy target |
|---|---|
| `web/` | `hosting:web` |
| `admin/` | `hosting:admin` |
| `functions/` | `functions` |
| `firestore.rules` / `firestore.indexes.json` | `firestore:rules` / `firestore:indexes` |
| Multiple surfaces | Combine into one deploy |
```

Standard Firebase commands:

```bash
firebase deploy --only hosting:TARGET --project PROJECT_ID
firebase deploy --only functions --project PROJECT_ID
firebase deploy --only firestore:rules --project PROJECT_ID
firebase deploy --only firestore:rules,functions,hosting:web --project PROJECT_ID
```

Validating rules before a real deploy is always fine:
`firebase deploy --only firestore:rules --dry-run`

---

## 4. Ship the whole loop

A change is not shipped until it is committed, pushed, and deployed. Do all three in one
session — do not end with the code committed but not deployed, or deployed but not committed.
An undeployed commit and an uncommitted deploy are both states that confuse the next session.

Order: verify locally → commit → push → deploy → record (see `kandr-worklog`).

Only create commits when the user has asked for them; if the repo's convention is that the
agent commits as part of shipping, that belongs in the project overlay.

---

## 5. Verification evidence

**Never report something as deployed without output proving it.**

Reporting a successful deploy from intent rather than evidence is how a broken build sits in
production for a day. The deploy command's own success output is the minimum bar.

When reporting, include:

- Which targets deployed
- The live URL for user-facing surfaces
- Anything that needs watching (function cold starts, index build time, cache TTL)

If a deploy fails, report the actual error. Do not retry the same command more than once
without changing something.

---

## Related skills

- `kandr-qa` — the regression gate that runs before deploy
- `kandr-functions` — server-side conventions and pre-deploy typecheck
- `kandr-ios-release` — the native app release path, which is gated differently
- `kandr-worklog` — recording what shipped
