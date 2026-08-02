# Cursor Skills & Rules Audit — August 2026

Full inventory and consolidation record for every Cursor skill and rule across `~/.cursor/` and `~/Apps/`.
This document is the checklist that drives the project-by-project (Phase 2) pass.

**Audit date:** 2026-08-02
**Scope at audit time:** 30 skills, 78 rule files, 14 projects, ~13,000 lines of agent instructions.

---

## 1. The architecture we are moving to

```
GLOBAL (~/.cursor/)
  rules/kandr-router.mdc      alwaysApply — trigger→skill table, the only always-on router
  skills/kandr-development    architect gate, extend-before-create, backward-compat verdict
  skills/kandr-qa             regression gate + production triage loop, evidence-first
  skills/kandr-functions      Cloud Functions naming, contracts, logging, idempotency
  skills/kandr-deploy         deploy-after-changes, deploy authority, verification evidence
  skills/kandr-ios-release    Fastlane, XcodeGen, Match, cert safety, keychain policy
  skills/kandr-worklog        CHANGELOG, BACKLOG, coding log, release notes

PROJECT (<repo>/.cursor/)
  rules/project-context.mdc   alwaysApply, <=80 lines, fixed section contract
  rules/kandr-overlay.mdc     alwaysApply, ~20 lines, project deltas only
  skills/<domain>             ONLY genuinely unique domain knowledge
```

**Rule of thumb:** global skills hold the *how*, project files hold the *what*.
If a line contains a project ID, bundle ID, domain, collection name, region, or lane name,
it belongs in the project overlay — not in a global skill.

The section contract for the two project files, the anti-patterns to avoid, and copyable
templates are in [`project-overlay-contract.md`](./project-overlay-contract.md) and
`../templates/cursor-rules/`.

---

## 2. What was duplicated (the reason for this work)

### 2.1 Fastlane / iOS deployment — 4 copies, ~60-70% identical

| File | Lines | Fate |
|---|---|---|
| `streaming-app/.cursor/rules/fastlane-deployment.mdc` | 648 | Reduce to overlay + Faith Music extras (App Clip, version table, metadata) |
| `radio-app/.cursor/rules/fastlane-deployment.mdc` | 171 | Reduce to overlay |
| `radio-app/.cursor/rules/deployment-agent.mdc` | 275 | Mostly re-duplicates the above — merge and shrink |
| `Fish On!/.cursor/rules/fastlane-deployment.mdc` | 103 | Reduce to overlay |
| `yard-sale/.cursor/skills/apple-deployment-expert/SKILL.md` | 140 | Reduce to overlay (already closest to target) |
| `_templates/cursor-rules/fastlane-deployment.mdc` | 41 | **Stale** — radio creds + deprecated ASC key. Replace with overlay template |

Content identical across 3+ of them, now living in `kandr-ios-release`:

- Homebrew Ruby PATH export
- ASC issuer ID `69a6de80-f231-47e3-e053-5b8c7c11a4d1`
- Apple Team ID `KNDYLHQ94J` (Kandr Media, LLC)
- Match: git-backed certs repo per app, `MATCH_PASSWORD` from `.env.local`
- Two-step `beta` → `deliver skip_binary_upload:true` (the 409 Redundant Binary Upload fix)
- `precheck_include_in_app_purchases:false`
- `api_key.json` regeneration one-liner
- Certificate safety: never revoke, delete stale keychain duplicates instead
- Common error table (bundler not found, train closed, profile mismatch)

### 2.2 `ios-development.mdc` — 3 near-copies

`radio-app` (40), `Fish On!` (36), `streaming-app` (40). The XcodeGen and Firestore-decode
sections are copy-paste with the app name swapped. Generic half moved to `kandr-ios-release`.

### 2.3 `cloud-functions-agent.mdc` — 5 copies, 3 different shapes

| Project | Lines | Shape |
|---|---|---|
| streaming-app | 34 | Thin pointer to `cloud-functions-architect` skill |
| kandr-crm | 45 | Full inline content |
| shopify-waypoint | 46 | Full inline content |
| pizzeria | 14 | Thin inline bullets |
| Hunter-Book-Club-Stephen | 12 | Thin inline bullets |

All five replaced by `kandr-functions` + a project overlay carrying region, secret names,
and genuinely local invariants.

### 2.4 `project-context.mdc` — 8 copies, no shared contract

Range: 15 lines (pizzeria) to 191 lines (streaming-app). Recurring sections were
Identifiers / Architecture / Firestore structure / Deploy. Now formalized as a fixed contract.

### 2.5 Deploy-after-changes — 5 different filenames, one job

`pizzeria/deploy-after-changes.mdc`, `shopify-waypoint/post-change-builds.mdc`,
`capacity-planner/deployment.mdc`, `pocs/Summer2026/trip-site-deploy-after-changes.mdc`,
and a deploy section buried inside `Hunter-Book-Club-Stephen/project-context.mdc`.
All replaced by `kandr-deploy` + a per-project path→target table.

---

## 3. Conflicts resolved (these were actively harmful)

| Conflict | Old state | Resolution |
|---|---|---|
| **Keychain unlock** | radio-app hardcodes `security unlock-keychain -p "<password>"`; streaming-app forbids agents from unlocking and says ask the user | `kandr-ios-release` adopts the streaming-app stance globally: never unlock non-interactively, ask the user |
| **ASC key ID** | radio-app uses `9C4UN5HNPV` and calls `6LF5PQ5KPG` deprecated; three other projects still use `6LF5PQ5KPG` | Not a shared fact. Lives in each project overlay |
| **Waypoint bundle model** | Global `waypoint-development` skill claims CDN77-hosted `waypoint.js` and starter/pro/enterprise pricing; project says extension-bundled `waypoint-bundle.js` and Basic/Growth/Pro | Removed from the global skill namespace. Archived at `shopify-waypoint/docs/legacy-waypoint-development-skill.md` with a wrongness header, for Phase 2 reconciliation. `shopify-waypoint/.cursor/` is canonical |
| **`security delete-certificate`** (found during implementation) | `local-toolchain.mdc` forbids the agent from running it; `streaming-app/fastlane-deployment.mdc` prescribes it as the fix for duplicate signing certs | `kandr-ios-release` keeps the full read-only diagnosis procedure but stops and hands the exact command to the user. Diagnose freely, never delete |

---

## 4. Misplaced globals corrected

| Item | Problem | Moved to |
|---|---|---|
| `~/.cursor/rules/design-system.mdc` | Globs `v2/src/**/*.tsx` — a Capacity Planner rule loaded in every project | `capacity-planner/.cursor/rules/` |
| `~/.cursor/skills/waypoint-development` | Single-project and factually stale | Deleted (project owns it) |
| `~/.cursor/skills/crm-public-api` | Single-project (kandr-crm-app) | `kandr-crm/.cursor/skills/` |
| `~/.cursor/skills/kandr-crm-redesign-campaign` | Single-project operator runbook | `kandr-crm/.cursor/skills/` |
| `~/.cursor/skills/kandr-stripe-access` | Near line-for-line duplicate of `stripe-integration.mdc` | Merged into the rule, skill deleted |
| `~/.cursor/skills/kandr-sentry` | Generic org conventions mixed with Faith Music + Radio setup runbooks | Org conventions stay global; app sections to be pushed down in Phase 2 |

---

## 5. `ryan-*` skills retired

The five generic skills in `kandr-bootstrap/.cursor/skills/` were good, vendor-neutral source
material that was never installed globally and never referenced by any project.

| Retired | Content absorbed into |
|---|---|
| `ryan-architect-mode` | `kandr-development` |
| `ryan-ops-loop` | `kandr-qa` (production triage loop section) |
| `ryan-changelog-release` | `kandr-worklog` |
| `ryan-ios-fastlane` | `kandr-ios-release` |
| `ryan-workstyle-bootstrap` | `kandr-workstyle` (kept as the bootstrap entrypoint, renamed) |

A stale May 2026 copy of `ryan-workstyle-bootstrap` in `kandr-crm/.cursor/skills/` was deleted.
It had a placeholder GitHub URL that would have misled any agent that read it.

---

## 6. Secrets

The secrets pass ran after the initial audit. GCP Secret Manager is now the source of truth,
reached through the `kandr-secrets` helper and a committed per-repo manifest. The playbook is
`~/.cursor/skills/kandr-secrets/SKILL.md`; this section records what the audit found.

### 6.1 What the cloud already held

Sixty-plus secrets across fourteen projects. Most inline credentials turned out to already
exist in Secret Manager, so the work was mostly referencing rather than migrating. Two
projects (`blueprint-kandr`, `wvfv-radio`) have the Secret Manager API disabled and hold
nothing.

### 6.2 Live bugs the audit surfaced

| Finding | Impact |
|---|---|
| `GEMINI_API_KEY` on `rlibbey-pocs` was the literal `PLACEHOLDER_..._ME` | The documented fallback in `nano-banana-images.mdc` could never work; only the hardcoded key kept image generation alive. Fixed by promoting the working key |
| `GEMINI_API_KEY` on `kandr-crm-app` was the literal `placeholder` | Non-empty, so it passed `if (!apiKey)` in `enrichFromGemini` and failed at the API call instead of skipping cleanly. Fixed |
| `aws-credentials.mdc` documented IAM user `main-admin-user` with a key ID that is not in use | The real credential is a different key resolving to the **account root**. Docs corrected; root-key rotation tracked separately |
| Both Stripe secrets on `rlibbey-pocs` are placeholders | `createInvoice` on kandr.io fails at call time. `handleStripeWebhook` is dormant — no endpoint is registered in Stripe for that project. Annotated, not silently patched |

### 6.3 What had to be created

Only the four Match passwords. Nothing else was missing. They now live as `MATCH_PASSWORD`
on `streamingapp-32dcb`, `kandr-radio-app`, `fishon-kandr-app`, and `yard-sale-3a062`, each
verified byte-exact — a trailing newline makes Match report a wrong-password error for a
value that is otherwise correct.

Mac login and keychain passwords were deliberately **not** stored. Per `kandr-ios-release`
the agent never unlocks the keychain, so there is nothing to store.

### 6.4 Sharing, which matters for rotation

AgentMail runs on four distinct keys, not one, and several are shared across projects.
Stripe's `sk_live` is duplicated across `streamingapp-32dcb` and `kandr-radio-app`. A secret
that appears in several projects exists as an independent copy in each, so rotating one means
updating every copy. The sharing map is in `~/.cursor/rules/agentmail.mdc`.

### 6.5 Remaining inline copies

Inline values were left in project rules by decision — removing them is Phase 2 work, done
per project. Their markers now name the cloud secret that supersedes them, so each removal is
mechanical:

```bash
rg "SECRET-AUDIT" ~/.cursor/rules ~/.cursor/skills ~/Apps --hidden --no-ignore -g '!*.jsonl'
```

The three global rules (`agentmail.mdc`, `aws-credentials.mdc`, `nano-banana-images.mdc`) are
already clean.

Out of scope: `~/.cursor/plans/`, `~/.cursor/worktrees/`, and agent transcripts. They are
historical artifacts rather than active instructions, but they do contain credential values.

---

## 7. Phase 2 checklist — project by project

Ordered by how much duplication each carries. Each project is done when it has a
compliant `project-context.mdc`, a `kandr-overlay.mdc`, and no rule that restates a global skill.

### 7.1 streaming-app (Faith Music) — 8 skills, 20 rules, 7,360 lines

- [ ] Cut `fastlane-deployment.mdc` (648 lines, `alwaysApply: true`) down to overlay + Faith Music extras: App Clip lane, version state table, metadata/screenshot paths, Sentry dSYM vars
- [ ] Slim `project-context.mdc` (191 lines, `alwaysApply: true`) to the section contract
- [ ] Delete `architect-agent.mdc` — absorbed by `kandr-development`
- [ ] Delete `regression-agent.mdc` — absorbed by `kandr-qa`; keep only the protected-domain→architect map in the overlay
- [ ] Delete `changelog.mdc` and `backlog-workflow.mdc` — absorbed by `kandr-worklog`
- [ ] Delete `cloud-functions-agent.mdc` — absorbed by `kandr-functions`; keep the CF catalog skill
- [ ] Delete `ios-build-safety.mdc` — absorbed by `kandr-deploy` / `kandr-ios-release`
- [ ] Collapse the thin wrapper rules (`auth-agent`, `stripe-agent`, `subscription-agent`, `content-architect.mdc`, `affiliate-agent`) into one overlay trigger table
- [ ] Merge `admin-console.mdc` + `admin-console-design.mdc`
- [ ] Add missing YAML frontmatter: `content-architect/SKILL.md`, `crm-regression-test/SKILL.md`, `affiliate-agent.mdc`, `content-architect.mdc`
- [ ] Keep as project skills: `cloud-functions-architect` (the ~128-function catalog), `content-architect` (Faith Music voice), `crashlytics-triage`, `crm-regression-test`, `daily-ops-stability-report`, `firebase-auth-architect`, `stripe-architect`, `subscription-source-of-truth`
- [ ] Receive the Faith Music section split out of global `kandr-sentry`

### 7.2 radio-app — DONE (2026-08-02)

Went from **11 rules / 1,380 lines / 1,031 always-loaded** to **6 rules / 369 lines /
202 always-loaded**, plus 6 on-demand skills. Reference model for the remaining projects.

- [x] Merged `deployment-agent.mdc` (285) and `fastlane-deployment.mdc` (181) into the
      `radio-deploy` **skill**, so a deploy runbook no longer loads on every turn
- [x] ASC key `9C4UN5HNPV`, Match repo, and lane names recorded in `kandr-overlay.mdc`
- [x] Keychain password moved to Secret Manager as `KEYCHAIN_PASSWORD` on `kandr-radio-app`
- [x] `ios-development.mdc` trimmed of XcodeGen content owned by `kandr-ios-release`
- [x] `project-context.mdc` 116 → 79, credentials removed, domain invariants made explicit
- [x] `project-manager.mdc` retired; `BACKLOG.json` migrated losslessly to `BACKLOG.md`
- [x] `crm-agent`, `notification-agent`, `payments-agent` converted to skills — all three
      self-described as "activates when the user mentions…", which is the skill pattern
- [x] `core-architect` 155 → 56; its 95-line system inventory became `radio-architecture`
- [x] `radio-sentry` skill already in place from Phase 1

Conflicts resolved rather than carried forward:

| Conflict | Resolution |
|---|---|
| `security unlock-keychain -p "<login password>"` marked MANDATORY, in 6 places | `kandr-ios-release` gained an opt-in path: projects that declare `KEYCHAIN_PASSWORD` in their manifest resolve it at build time. Radio opts in because WVFV and FMR build sequentially and the keychain relocks between them |
| `match nuke` prescribed as escalation step 6 and as an error fix | Removed. The ladder now stops at `force:true` and hands off to the user |
| The two deploy rules contradicted each other on `bundle exec fastlane` vs `fastlane` | Standardized on `bundle exec`. The Bundler-mismatch warning that argued against it is stale — `Gemfile.lock` pins 4.0.6 and 4.0.6 is installed |

Also corrected during this pass: **Fastlane never auto-loads `.env.local`.** Its dotenv helper
reads only `.env` and `.env.default`; `.env.local` needs `--env local`. streaming-app, radio-app,
and Fish On! must therefore use `ios/fastlane/.env`. yard-sale and garagesale-legacy are the
exception — their Fastfiles hand-roll a `.env.local` reader at the top.

### 7.3 Fish On! — 5 rules

- [ ] Reduce `fastlane-deployment.mdc` (103) to overlay; keep the cert/profile table and `setup_certs` lane note
- [ ] Slim `ios-development.mdc`
- [ ] Keep `brand-style-guide.mdc` and `project-context.mdc`
- [ ] `kandr-branding.mdc` (12 lines, "Kandr not Candor") is generic — promote to global or keep duplicated deliberately

### 7.4 AK Consulting (Phoenix) — 3 skills, 7 rules, AGENTS.md

- [ ] Shrink `phoenix-deploy.mdc` to a pointer — it duplicates ~80% of `phoenix-deploy/SKILL.md`
- [ ] Keep `phoenix-design-system.mdc` as-is — it is already the correct pointer pattern and is the model for this whole effort
- [ ] Delete `coding-log.mdc` — absorbed by `kandr-worklog` (configure the path as `docs/CODING_LOG.md` in the overlay)
- [ ] Delete `phoenix-task-lists.mdc` — the no-time-estimates rule is now global in `kandr-worklog`
- [ ] Keep `phoenix-governance.mdc`, `phoenix-api-design.mdc`, `project-context.mdc`, and the three Phoenix skills

### 7.5 shopify-waypoint — 2 skills, 4 rules

- [ ] Absorb the still-accurate parts of the deleted global `waypoint-development` skill into the project (GCP secrets, KMS, CDN77 data URLs, emulator ports, API route catalog) — verify each fact against the code before copying, since the global version was stale
- [ ] Reduce `cloud-functions-agent.mdc` to overlay deltas
- [ ] Reduce `post-change-builds.mdc` to the path→target table
- [ ] Keep `theme-settings-ownership.mdc`, both storefront skills, and the Sentry→Linear automation

### 7.6 kandr-crm — 1 skill, 2 rules

- [ ] Receive `crm-public-api` and `kandr-crm-redesign-campaign` from global
- [ ] Reduce `cloud-functions-agent.mdc` (45) to overlay deltas (multi-tenant `companyId`, secrets, email pattern)
- [ ] Slim `project-context.mdc` (73) to the contract

### 7.7 capacity-planner — 14 rules

- [ ] Receive `design-system.mdc` from global
- [ ] Add YAML frontmatter — 13 of 14 rules have none
- [ ] Reduce `regression.mdc` and `agent-run-commands.mdc` to overlay deltas
- [ ] Otherwise leave alone. This is the best-decomposed ruleset in the estate; the domain rules
      (`capacity-calculations`, `data-model`, `audit-trail`, `navigation-scaffolding`, `ui-patterns`)
      are appropriately specific and should not be touched

### 7.8 yard-sale — 2 skills, 3 rules

- [ ] Already matches the target shape. Reduce `apple-deployment-expert/SKILL.md` to the delta table now that `kandr-ios-release` owns the generic workflow
- [ ] Delete `git-pull-on-session.mdc` — duplicates the global `project-startup.mdc`
- [ ] Keep `apple-iap-expert` and both routing rules (this is where the routing pattern came from)

### 7.9 bill-agentic — 1 skill, 2 rules

- [ ] Reduce `platform-standards.mdc` to a pointer to `bill-platform-feature/SKILL.md` — they currently restate each other
- [ ] Keep `dev-servers.mdc`

### 7.10 Small projects

- [ ] **pizzeria** — reduce `cloud-functions-agent.mdc` and `deploy-after-changes.mdc` to overlay deltas
- [ ] **Hunter-Book-Club-Stephen** — same, plus extract the deploy section out of `project-context.mdc`
- [ ] **pocs/Summer2026** — reduce `trip-site-deploy-after-changes.mdc` to the path→target table
- [ ] **sunny-slope-haus** — add frontmatter to `sunny-slope-haus.mdc`, rename to `project-context.mdc`
- [ ] **kandr.io** — has no `.cursor/` at all. Add `project-context.mdc` + overlay
- [ ] **_templates/cursor-rules/** — replace the stale radio-derived templates with the overlay contract

---

## 8. Decisions on file placement, for future reference

Things deliberately **not** made global:

- **Design systems.** Every one found (`phoenix-design-system`, capacity-planner `ui-patterns`,
  Fish On! `brand-style-guide`, streaming `admin-console-design`) is genuinely brand-specific.
  A shared "admin layout" skill would be thin and would fight the per-brand rules.
- **Project context.** Only the *section contract* is shared; the content never is.
- **Cloud Functions catalogs.** The Faith Music catalog is ~128 real function names. That is
  project data, not a pattern.
- **Content/voice guides.** Faith Music's voice pillars are ~92% project-specific.

Things deliberately kept as always-on global rules:

- `kandr-router.mdc` — the router, plus every standing safety rule
- `project-startup.mdc` — git pull on first open
- `i-have-adhd-default.mdc` — communication style
- `project-bootstrap.mdc` — greenfield interception, and the guard against firing in an existing repo

## Global reference conversion (done 2026-08-02)

The five reference fact-sheets were converted to on-demand skills, and `local-toolchain.mdc` was
split. Global always-on went from **545 lines to 134**.

| Was (always-on rule) | Now |
|---|---|
| `stripe-integration.mdc` (95) | `kandr-stripe` skill |
| `aws-credentials.mdc` (78) | `kandr-aws` skill |
| `nano-banana-images.mdc` (74) | `kandr-images` skill |
| `firebase-projects.mdc` (63) | `kandr-firebase` skill |
| `agentmail.mdc` (63) | `kandr-email` skill |
| `local-toolchain.mdc` (63) | tool table → `kandr-machine` skill; safety rules → router |

The safety content did **not** become on-demand. Anything that must fire without a trigger — the
destructive-operation prohibitions, the client-Stripe-key rule, "never use `GenerateImage`", and
"the toolchain is installed, do not verify it" — moved into `kandr-router.mdc`, which grew from 36
to 79 lines. The reference data behind each is what became loadable on demand.

The global layer is mirrored into this repo under `.cursor/rules/` and `.cursor/skills/` so it is
version controlled; `~/.cursor` itself is not a git repo.
