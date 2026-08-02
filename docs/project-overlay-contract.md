# Project overlay contract

Every project converges on the same two always-on rule files. Everything else in a project's
`.cursor/` should be either a genuinely unique domain skill, a subagent that does multi-step
work, or nothing at all.

```
<repo>/.cursor/
  rules/project-context.mdc    alwaysApply, <=80 lines, fixed sections
  rules/kandr-overlay.mdc      alwaysApply, ~40-80 lines, deltas only
  skills/<domain>/SKILL.md     ONLY unique domain knowledge
  agents/<name>.md             ONLY delegatable multi-step work
```

The global `kandr-*` skills hold the **how**. These two rule files hold the **what**.
For the wider picture — the four ownership layers and where secrets go — see
`instruction-architecture.md`.

## Skills and subagents are both real, and different

`.cursor/agents/*.md` is a supported Cursor feature. Files there are **subagents**: they need
`name` and `description` frontmatter, they auto-delegate on description match, and they can be
invoked with `/name`. Cursor also reads `.claude/agents/` and `.codex/agents/` for compatibility.

A subagent runs in **its own context window** and returns one message. That makes the choice
straightforward:

- **Skill** — a reference the current conversation should absorb. Voice guides, catalogs,
  architecture maps, release procedure.
- **Subagent** — work you would rather not spend the main context on. A long review, a release
  run, an independent verification of something already built.

A subagent whose body is purely knowledge should be a skill. A subagent that duplicates a skill
should shrink to a thin file that reads the skill and states its non-negotiables — see
`streaming-app/.cursor/agents/release-manager.md` for the reference shape.

**Frontmatter is not optional.** A skill without `name` and `description`, or a subagent without
`description`, can never be selected automatically. Faith Music had six such files sitting inert,
including a 412-line voice guide.

## The test

Before writing a line into a project rule, ask: *would this sentence be true in another
Kandr project?*

- **Yes** → it belongs in a global skill. Do not restate it here.
- **No** → it belongs in one of these two files.

A project rule that says "run `tsc --noEmit` before deploying" is duplication — `kandr-deploy`
already says it. A project rule that says "typecheck `functions/`, `admin-console/`, and `web/`"
is a delta, and belongs in the overlay.

## When to add a project skill

Add one only when the knowledge is substantial, unique, and would bloat the overlay:

- A catalog of real names (the ~128 Cloud Functions in Faith Music)
- A brand voice or design system (Phoenix design system, Faith Music content voice)
- A domain workflow with no analogue elsewhere (Waypoint theme settings cascade)

Do **not** add a project skill that is mostly a restatement of a global one with a project
name swapped in. That is the pattern this consolidation removed.

## Anti-patterns

| Pattern | Why it failed | What to do instead |
|---|---|---|
| A thin `*-agent.mdc` rule per domain whose only job is "read skill X" | Faith Music accumulated six of them | One trigger table in the overlay |
| A 648-line `alwaysApply: true` rule | Loaded on every turn regardless of relevance | Overlay + on-demand skill |
| Copying a rule between projects and editing the app name | Produced four Fastlane rules that drifted apart and contradicted each other | Global skill + per-project deltas |
| Restating a global safety rule "so it doesn't get missed" | Creates a second copy that goes stale and then conflicts | Trust the global skill; the router makes it always-on |

## Frontmatter

Both files need it. Roughly a third of the rules in the estate had none, which makes them
invisible to description-based matching.

```yaml
---
description: One line. What this covers and when it applies.
alwaysApply: true
---
```

Use `alwaysApply: false` with `globs:` for anything that only matters in one directory.

---

## Template: `project-context.mdc`

Target: 80 lines or fewer. Facts only — no process, no workflow.

```markdown
---
description: Core identifiers, architecture, and domain invariants for <APP NAME>
alwaysApply: true
---

# <APP NAME> — Project Context

## Identifiers

| Setting | Value |
|---|---|
| Firebase project | `<project-id>` |
| Primary URL | `<domain>` |
| GitHub repo | `<org/repo>` |
| Functions runtime / region | Node 22 / `<region>` |
| Bundle ID (if native) | `<bundle.id>` |

## Architecture

Two or three sentences: what this is, the stack, and the tenancy model if there is one.
Then the surfaces:

- `web/` — <what it is>
- `admin-console/` — <what it is>
- `functions/` — <what it is>
- `ios/` — <what it is>

## Data model

Collections and their purpose. Paths and scoping keys, not full schemas —
schemas belong in the code.

- `<collection>` — <purpose, scoping key>

## Domain invariants

Rules that are true in this project and nowhere else. The things that break
if someone does not know them.

- <invariant>
```

---

## Template: `kandr-overlay.mdc`

Target: 20-40 lines. **Deltas only.** If a line would be true in another project, delete it.

```markdown
---
description: Project deltas for the shared kandr-* skills — deploy targets, verification commands, protected domains, and release identifiers
alwaysApply: true
---

# <APP NAME> — kandr skill overlay

The shared `kandr-*` skills define the process. This file supplies the values for this repo.

## Verification commands (kandr-qa)

| Gate | Command |
|---|---|
| Typecheck | `npx tsc --noEmit` in `functions/`, `admin-console/` |
| Lint | `<command>` |
| Build | `<command>` |

## Deploy targets (kandr-deploy)

| Changed paths | Deploy target |
|---|---|
| `web/` | `hosting:web` |
| `admin-console/` | `hosting:admin` |
| `functions/` | `functions` |
| `firestore.rules` / `firestore.indexes.json` | `firestore:rules` / `firestore:indexes` |

Firebase project: `<project-id>`
Live URLs: <list>

## Protected domains (kandr-qa)

Consult the named skill before editing these paths:

| Path | Consult first |
|---|---|
| `<path>` | `<skill>` |

## Cloud Functions deltas (kandr-functions)

- Region: `<region>`
- Tenant scoping key: `<field>`

## Secrets (kandr-secrets)

Names live in the repo's committed `.kandr-secrets` manifest, not here — one source of truth,
and the helper can read it. This section records only what the manifest cannot express:

- GCP project holding the secrets: `<project-id>`
- Secrets shared with other projects (rotating affects them too): `<NAME>` → `<projects>`
- Known placeholders or gaps: `<NAME>` and what it blocks

## iOS release deltas (kandr-ios-release)

Delete this section if the project has no native app.

| Setting | Value |
|---|---|
| Bundle ID | `<bundle.id>` |
| ASC app ID | `<id>` |
| ASC API key ID | `<key-id>` |
| Match repo | `<org/repo-certs>` |
| MATCH_PASSWORD | Secret Manager → `kandr-secrets env ios/fastlane/.env --group fastlane` |
| Lanes | `<lane>`, `<lane>` |
| Project path / scheme | `ios/` / `<Scheme>` |

Project-specific quirks: <e.g. Watch target must be version-bumped too; App Clip needs
`ensure_app_clip` before deliver>

## Work log paths (kandr-worklog)

- Changelog: `CHANGELOG.md`
- Backlog: `BACKLOG.md`
- Area tags: `[iOS]`, `[Admin]`, `[Functions]`
```

---

## Conflict resolution

Where an overlay gives a concrete value, it wins — that is its job.

Where an overlay contradicts a **safety rule** in a global skill, the skill wins and the
contradiction gets raised with the user. The keychain-unlock conflict is the worked example:
radio-app's rule hardcoded an unlock command with a password, `kandr-ios-release` forbids
unlocking non-interactively, and the skill's rule stands.
