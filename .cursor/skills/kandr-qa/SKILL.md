---
name: kandr-qa
description: Regression and QA gate for any Kandr project, plus the production triage loop. Use when the user says regression mode, review the code, QA this, sanity check, before we ship, or validate this; automatically after a multi-bug fix cycle; and when investigating a crash, an incident, a CI failure, or a production bug report.
---

# QA and regression

Two jobs live here because they answer the same question from opposite ends:
**pre-ship regression** asks "is this about to break something," and the
**triage loop** asks "what already broke."

Project-specific commands (which packages to typecheck, which domains are protected,
which architect doc to consult) live in that repo's `kandr-overlay.mdc`.

---

## Part 1 — Pre-ship regression gate

### When to run it

1. **The user says a trigger phrase**, including:
   - "regression mode", "go into regression mode"
   - "review the code", "review", "do a review", "final review"
   - "check the code", "check this", "sanity check"
   - "is this solid", "make it solid", "solidify"
   - "regression test", "QA this", "QA check"
   - "before we ship", "before we push", "validate this"

2. **Automatically after a fix cycle** — any session where three or more bugs were identified
   and fixed triggers a regression review before committing or deploying.

3. **Before touching a protected domain.** Each project lists its protected paths and the
   architect doc or skill to consult first in `kandr-overlay.mdc`. Typical protected domains:
   payments, auth, subscriptions/entitlements, push notification delivery, CRM sends.

### Never skip it when

- A server function is being redeployed
- A data model field is being added, renamed, or removed
- A shared TypeScript interface or Swift model is changing
- An app-lifecycle file is being modified (`AppDelegate`, root state managers, `@Published` properties)

### How to run it

1. Determine what changed this session: `git diff --name-only HEAD`
2. Consult the architect doc or skill for each domain touched
3. Run the gates:
   - **Typecheck** — `npx tsc --noEmit` in every package with changes
   - **Lint** — on changed files only, not the whole repo
   - **Build** — if the project has a build step that catches more than tsc does
   - **Schema check** — field names in code match the stored documents
   - **Security check** — no secret in a client-readable path, no loosened auth by accident
   - **Regression check** — no previously fixed bug reintroduced
4. Fix every CRITICAL and HIGH finding immediately, then re-review
5. Declare clean only when zero CRITICAL/HIGH remain

A clean review is **required before any commit or deploy** that touches server functions
or native app code.

### Verdict block

```
## Regression Review

**Verdict**: PASS | FAIL

| Gate | Result |
|---|---|
| Typecheck | PASS / FAIL |
| Lint (changed files) | PASS / FAIL |
| Build | PASS / FAIL / N/A |
| Schema integrity | PASS / FAIL |
| Security | PASS / FAIL |

### Findings
- CRITICAL / HIGH / MEDIUM / LOW — one line each, with file:line

### Notes
(what was fixed during review, what remains deferred and why)
```

Order findings by severity. Fix CRITICAL and HIGH before reporting; list MEDIUM and LOW
as follow-ups rather than blocking on them.

---

## Part 2 — Production triage loop

For incidents, crash reports, CI failures, and bug reports from real users.

1. **Triage** — state the user-visible symptom and its severity. Identify the owning system
   (client, functions, infrastructure, third party).
2. **Reproduce** — get exact steps and logs. Reduce to a minimal repro. If you cannot
   reproduce it, say so rather than guessing at a fix.
3. **Fix** — smallest safe change first.
4. **Verify** — run the narrowest check that proves correctness.
5. **Ship** — follow `kandr-deploy`.
6. **Record** — follow `kandr-worklog`. Note follow-ups.

### Operating safety

- Prefer reversible changes.
- No "big bang" refactors during incident response. Stabilize first, refactor later.
- Never claim success without verification evidence.

---

## Part 3 — Evidence-first rule

**Never report the state of a production system without live tool output.**

This applies to crash counts, error rates, payment status, subscription state, deploy status,
and log contents. Saying "this looks fixed" or "there are no more crashes" without having
queried the tool is the single most damaging failure mode in this work — it ends the
investigation while the bug is still live.

If the tool is unavailable or unauthenticated, say so and stop. Do not substitute inference.

### Triaging reported issues

Classify before fixing:

| Class | Meaning | Action |
|---|---|---|
| **ACTIVE** | Occurring in the current release | Fix now |
| **REGRESSED** | Was fixed, has returned | Fix now, and find why the fix did not hold |
| **WATCH** | Occurring at low volume or in an edge case | Log it, do not derail the session |
| **LEGACY** | Only in versions no longer distributed | Do not fix. Confirm the version range first |

Only propose fixes for ACTIVE and REGRESSED. Fixing a LEGACY crash burns a session on
code no user runs.

Always check the version range before concluding anything. An issue with 400 events that
all landed on a build from four releases ago is not a current problem.

---

## Related skills

- `kandr-development` — the backward-compatibility gate that runs before this one
- `kandr-deploy` — shipping the fix
- `kandr-worklog` — recording it
- `kandr-sentry` — org-wide Sentry conventions for production error triage
