---
name: kandr-development
description: How to plan and build a change across any Kandr project — when to blueprint before coding, the extend-before-create rule, and the backward-compatibility review gate with a CLEAR/CAUTION/BLOCKED verdict. Use when starting a feature, designing an API or data model, refactoring, or finishing an implementation and about to report it as done.
---

# Development workflow

The default posture across every Kandr project: **understand what exists, extend it rather than
duplicate it, and prove the change is backward compatible before calling it done.**

Project-specific identifiers (collection names, function names, bundle IDs, hosting targets)
live in that repo's `project-context.mdc` and `kandr-overlay.mdc`. This skill is the process.

---

## 1. Architect first, when it earns it

Switch into architect mode — produce a blueprint before writing code — when any of these hold:

- There are multiple valid implementations with real trade-offs.
- The change crosses frontend / backend / infrastructure boundaries.
- It needs a sequence: migrations, staged rollout, a release train.
- Requirements are ambiguous enough that you would otherwise ask three or more questions.

Skip it for a single-file fix, a copy change, or an obvious bug with one correct answer.
Blueprinting a two-line fix wastes the user's time.

### Blueprint contents

- Key decisions and the default chosen for each
- Files to create or modify, **by path**
- Data flow, if the change moves data between systems
- Verification plan: which lint, typecheck, test, or manual check proves it works
- Rollout plan, if the change is risky or irreversible

### Build sequence

Order the work so execution is mechanical: scaffold → core logic → wire UI/API →
add verification → ship.

---

## 2. Extend before you create

Before adding a new module, endpoint, Cloud Function, utility, or component:

1. **Search first.** Look for an existing thing in the same domain that already does most of it.
2. **Prefer extending.** Adding a parameter or a branch to a working function beats a new
   near-duplicate that will drift.
3. **Ask before creating.** If a new export, route, collection, or top-level module really is
   needed, confirm with the user before writing it.
4. **Augment, don't fragment.** Three functions that each do 80% of the same thing is the
   failure mode this rule exists to prevent.

The one exception: if extending would force a breaking signature change on something a shipped
client calls, create a new version alongside the old and deprecate on a schedule.

---

## 3. Backward-compatibility review gate

Run this at the end of every plan (before the user confirms) and at the end of every
implementation (before announcing completion). Report the verdict.

Old clients do not update on your schedule. A shipped iOS app from six months ago is still
calling your functions and decoding your documents.

### Data model

- No field renames or removals on documents read by shipped clients
- No type changes (string→number, optional→required)
- New fields are optional or have server-side defaults — old clients will not write them
- No collection renames or path restructuring
- Indexes are additive only; removing one breaks live queries
- **Safe pattern:** add optional fields, keep old fields until all clients update, migrate at write time

### API contracts

- No renamed or removed callable/endpoint exports — old clients call by name
- No new *required* request parameters
- No removed response fields a client depends on
- **Safe pattern:** version new functions alongside old, keep old signatures as thin wrappers

### Security rules

- No tightened access on paths the live app reads or writes — this fails silently on users' devices
- No new auth requirements on currently public paths
- **Safe pattern:** loosen or add freely, tighten only after confirming no active client relies on the old rule

### Client models

- Swift `Codable` and TypeScript models must still decode existing stored documents
- New non-optional properties without defaults will crash on old documents
- **Safe pattern:** new properties are optional or defaulted; never remove a property while old docs exist

### Routing and deep links

- No changed URL scheme or path format — already-sent push notifications reference the old ones
- No removed routes
- **Safe pattern:** support old paths alongside new

### Payments and entitlements

- Nothing that could double-charge, lose an entitlement, or break the payment→entitlement pipeline
- Webhook handlers stay idempotent
- Never remove an entitlement sync pathway

### General

- Behavioral changes gate behind a feature flag
- Secrets stay in server-only config, never in a client-readable path

---

## 4. Verdict block

Include this in your response:

```
## Architect Review

**Verdict**: CLEAR | CAUTION | BLOCKED

- [ ] Data model: no breaking changes
- [ ] API contracts: no signature breaks
- [ ] Security rules: no access regressions
- [ ] Client models: decode-safe
- [ ] Routing: no broken paths
- [ ] Payments: no entitlement risk

### Notes
(concerns, migration steps, conditions for safe deployment)
```

- **CLEAR** — no compatibility risk, safe to proceed
- **CAUTION** — minor risk with mitigations noted, proceed with care
- **BLOCKED** — breaking change detected, revise before implementing

If BLOCKED, propose a revised approach that preserves compatibility rather than asking the
user whether to break it.

Skip the block entirely for changes that touch no shared contract — a copy tweak, a comment,
a local-only refactor. Emitting a six-line checklist for a typo fix is noise.

---

## 5. Related skills

- `kandr-qa` — the regression gate that runs after this one, and the production triage loop
- `kandr-functions` — server-side naming, contracts, and logging conventions
- `kandr-deploy` — what the agent may deploy and what needs permission
- `kandr-worklog` — recording what changed once it ships
