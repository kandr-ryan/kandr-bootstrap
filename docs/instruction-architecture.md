# Instruction architecture

How agent instructions, secrets, and state are layered across every Kandr project. This is the
top-level frame. `project-overlay-contract.md` covers the project layer in detail.

Two questions decide where anything goes:

1. **Who owns it** — Kandr, or a specific client?
2. **When does it load** — every request, or only when relevant?

The first question gives the four layers. The second is the one that costs money, because
always-on text is charged on every turn whether or not it is relevant.

---

## The four layers

| Layer | Owns | Lives in |
|---|---|---|
| 1. Kandr conventions | How we work and build, everywhere | `~/.cursor/rules/`, `~/.cursor/skills/kandr-*` — symlinks into `kandr-bootstrap/global/` |
| 2. Kandr secrets | Our credentials | GCP Secret Manager, pointed to by `.kandr-secrets` |
| 3. Client secrets | A client's own credentials | That app's per-tenant storage. **Never** Secret Manager |
| 4. Project knowledge | What this app is and how it is wired | `<repo>/.cursor/` |

### Layer 1 — Kandr conventions

One always-on router (`kandr-router.mdc`) plus on-demand `kandr-*` skills.

The router carries only the standing rules that need no trigger — never ship a native build
without an explicit request, never revoke a certificate or run `match nuke`, never report deploy
or production state without tool output proving it, never commit a secret. Everything else is a
skill that loads when the work matches its description.

A global rule should exist only if it is a safety rule, a machine-level constraint, or a router.
Reference data — API patterns, account tables, service configuration — belongs in a skill.

### Layer 2 — Kandr secrets

**GCP Secret Manager is the only store.** No credential value belongs in a rule, a skill, a
committed file, or a chat message.

Each repo carries a `.kandr-secrets` manifest listing *names only*, which is safe to commit:

```
[runtime]
STRIPE_SECRET_KEY=streamingapp-32dcb
AWS_ACCESS_KEY_ID=streamingapp-32dcb:aws-access-key   # local name : remote name

[fastlane]
MATCH_PASSWORD=streamingapp-32dcb
```

The `kandr-secrets` helper resolves values at runtime — `load` for a shell, `env` to generate a
gitignored dotenv, `doctor` to diagnose. Groups exist because a Fastlane secret and a Cloud
Functions secret have different consumers.

Cloud Functions bind secrets directly through Firebase rather than fetching them. See the
`kandr-secrets` skill for the full workflow.

### Layer 3 — Client secrets

A client's credential is not ours to hold. It lives in the application's own per-tenant storage,
entered by the client, readable only by the server.

**The ownership test:** if this key were compromised, who has to go rotate it? If the client
would call us, it is ours and belongs in Secret Manager. If we would call the client, it is
theirs and belongs in app storage.

Worked examples:

| Credential | Owner | Where it lives |
|---|---|---|
| Platform subscription Stripe key | Kandr | Firebase secret `STRIPE_SECRET_KEY` |
| A radio station's donation Stripe key | The station | Firestore `stations/{id}` config |
| Faith Music's donation Stripe key | The client | Firestore `privateConfig/donateConfig` |
| `AGENTMAIL_API_KEY` for our own domains | Kandr | Secret Manager |
| A CRM client's own AgentMail key | The client | That tenant's config document |

Client secrets must be unreadable from the client SDK. The Faith Music pattern is the reference:
`config/` is world-readable so the plans page can load without auth, therefore **no key may ever
sit in `config/`**. Keys go in `privateConfig/`, which is `allow read, write: if false` and
reachable only by Cloud Functions through the Admin SDK, with the admin console going through
callable functions rather than direct reads.

### Layer 4 — Project knowledge

Four artifacts with different jobs. See `project-overlay-contract.md` for the full contract.

| Artifact | Load | Holds |
|---|---|---|
| `rules/project-context.mdc` | always | Invariants that must hold on every request |
| `rules/kandr-overlay.mdc` | always | The values that fill in the global skills' blanks |
| `skills/<name>/SKILL.md` | on match | Domain knowledge, inventories, maps |
| `agents/<name>.md` | on delegation | Multi-step work worth isolating in its own context |

---

## Load mechanics, and why they matter

| Mechanism | Cost per request | Use for |
|---|---|---|
| `alwaysApply: true` rule | **Full text, every turn** | Safety rules, invariants, routing |
| Rule with `globs` | Full text when a matching file is touched | Conventions tied to a directory |
| Skill | Description always; body when selected | Knowledge, process, playbooks |
| Subagent | Description always; body in its own window | Delegatable multi-step work |
| State file | Nothing until read | Data that changes |

A subagent's body never enters the parent context, so a long subagent is cheap. A long always-on
rule is not. This is the single most useful thing to know when deciding where something goes.

**Skill or subagent?** A skill informs the current conversation. A subagent goes away, does
something, and reports back. If it is a reference document, make it a skill. If it does work in
several steps and you would rather not spend the main context on it, make it a subagent. A
subagent that is only a knowledge document should be a skill, and a subagent that duplicates a
skill should be reduced to a thin file that reads the skill.

---

## State is not instruction

Instructions describe how to do a thing. State records what is currently true. Putting state
inside an always-on rule means it goes stale silently and costs tokens on every turn — Faith
Music's version table sat inside a rule claiming a version that was three weeks out of date.

The division:

- The **global skill** defines the format
- The **overlay** names the path
- The **file** holds the data

| File | Holds |
|---|---|
| `CHANGELOG.md` | What was done, per session |
| `BACKLOG.md` | What is left to do |
| `ios/DEPLOY_STATE.json` | Current App Store and TestFlight versions |
| `ios/DEPLOYMENT_LEARNINGS.md` | Incidents worth not repeating |

---

## Precedence

- **The overlay wins on values.** Project IDs, lane names, hosting targets, collection names.
- **The skill wins on safety.** Where a project contradicts a global safety rule, the skill
  governs and the contradiction gets raised with the user rather than silently resolved.
- **Project beats global** on the same name; `.cursor/` beats `.claude/` and `.codex/`.

---

## The test, before writing anything

**Would this sentence be true in another Kandr project?**

- Yes, and it is a safety rule → global rule
- Yes, and it is process → global skill
- No, and it is a value → project overlay
- No, and it is substantial knowledge → project skill
- It changes over time → a state file, not an instruction

Duplicating something "so it does not get missed" creates a second copy that drifts and then
contradicts the first. That is exactly how Faith Music ended up with two deployment sources
disagreeing about `bundle exec`, both holding the same password inline.
