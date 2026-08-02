## kandr-bootstrap (vendor-neutral bootstrap)

**TL;DR**: Run one command to install a safe-by-default macOS dev toolchain **and** get a shareable Cursor Skill that teaches Cursor/agents how to use the setup.

Shareable **macOS bootstrap installer** + a **Cursor Skill bundle** that documents a pragmatic “how I work” setup.

This repo is meant to be **comprehensive but vendor-neutral**: it includes workflows and operational playbooks, but **no project-specific secrets, private repos, or org-specific constants**.

If you want a new machine to be productive quickly (without hand-installing a dozen CLIs, and without risky auto-configuration), this repo gives you:
- a safe-by-default installer (`install.sh`)
- a shareable set of Cursor Skills (`global/skills/*`) that capture workflows + conventions (bootstrap + release + ops)

### Global Cursor layer

`global/` holds the agent configuration that applies in every repo — the always-on rules, the
shared skills, and the scripts those skills invoke. `~/.cursor/rules`, `~/.cursor/skills`, and
`~/.cursor/scripts` are symlinks into it, so there is exactly one copy and it is version
controlled. Link it on a new machine with:

```bash
./scripts/link-global-cursor.sh
```

See [`global/README.md`](global/README.md) for the layout and
[`docs/instruction-architecture.md`](docs/instruction-architecture.md) for the model behind it.

### Cursor quick prompt

After cloning this repo (or copying the skill into a project), open the skill file in Cursor and say:

> “Use the skills in `global/skills/` as guidance. Start with `kandr-workstyle` to bootstrap this machine (summarize bundles/flags and recommend a default). Then explain when to use `kandr-development`, `kandr-qa`, `kandr-functions`, `kandr-deploy`, `kandr-ios-release`, and `kandr-worklog` as ongoing ways-of-working.”

If you already have a big local workspace (e.g. `~/Apps/*`) with existing Cursor rules/skills, also say:

> “Run the local inventory script `scripts/index-local-cursor-assets.sh` (if present) and use it to reference existing skills/rules across my projects without hardcoding paths in the shared docs.”

### Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/kandr-ryan/kandr-bootstrap/main/install.sh | bash
```

### Share card (OpenGraph)

- SVG: `assets/og-bootstrap-setup.svg` (1200×630)
- If you need a PNG, you can export locally (example using librsvg):

```bash
brew install librsvg
rsvg-convert assets/og-bootstrap-setup.svg -w 1200 -h 630 -o og-bootstrap-setup.png
```

### What happens when you run it

- **Interactive menu** asks which bundles to install (everything is skipable).
- Default behavior is **install missing only**.
- If you pass `--upgrade`, it will upgrade packages it manages (brew/npm/gem), otherwise it won’t.
- It can optionally prompt to run auth flows (`--with-auth`), but won’t force logins.

### Benefits (what you get)

- **A predictable baseline toolchain** for modern JS/TS + Firebase + GCP workflows.
- **Optional iOS release tooling** (Fastlane/CocoaPods/XcodeGen) without forcing it on everyone.
- **Optional integrations** (Stripe/Linear/Claude Code) so your “power tools” are one flag away.
- **Safety guarantees**: no shell profile edits, no surprise upgrades, no credential changes without prompts.

### What it installs

Safe defaults: **installs missing tools only**, upgrades only with `--upgrade`.

- **Core (default on)**: Homebrew, git, gh, node, jq, gcloud, firebase
- **Integrations (optional)**: Stripe CLI, Linear CLI, Claude Code
- **Docker (optional)**: Docker Desktop
- **iOS (optional)**: Homebrew Ruby, bundler, fastlane, cocoapods, xcodegen (Xcode is manual)
- **Extras (optional)**: ripgrep
- **Auth (optional)**: prompts to run `gh auth login`, `gcloud auth login`, `gcloud auth application-default login`, `firebase login`

### What it does NOT do

- Does **not** edit `~/.zshrc`, `~/.zprofile`, etc.
- Does **not** upgrade anything unless you provide `--upgrade`
- Does **not** install Xcode automatically (it prints the manual steps instead)
- Does **not** store or generate API keys/secrets

### Examples

```bash
./install.sh
./install.sh --with-core --with-integrations
./install.sh --with-core --with-ios --upgrade
./install.sh --dry-run
```

### Options (common)

- `--dry-run`: print actions without executing
- `--upgrade`: allow upgrades for already-installed tools
- `--non-interactive`: don’t prompt (use explicit `--with-*` / `--skip-*`)

### Cursor Skills

This repo ships a shareable skill bundle under `global/skills/`:

| Skill | Covers |
|---|---|
| `kandr-workstyle` | Entrypoint: bootstrap script, core principles, rules vs skills vs hooks |
| `kandr-development` | Architect gate, extend-before-create, backward-compatibility review |
| `kandr-qa` | Regression gate before shipping, production triage loop, evidence-first rule |
| `kandr-functions` | Cloud Functions naming, contracts, logging, webhook idempotency |
| `kandr-deploy` | Deploy authority, path→target table, verification evidence |
| `kandr-ios-release` | Fastlane, XcodeGen, Match, certificate and keychain safety |
| `kandr-secrets` | GCP Secret Manager as source of truth, per-repo manifests, the `kandr-secrets` helper |
| `kandr-worklog` | Changelog, backlog, release notes |

Run `./scripts/link-global-cursor.sh` to symlink them into `~/.cursor/` and make them available
in every project, or copy an individual folder into a single repo's `.cursor/skills/` to scope it
to that project.

`kandr-secrets` also ships a helper at `scripts/kandr-secrets.sh`. Install it once so secrets
resolve from the cloud without ever being pasted into a file:

```bash
cp scripts/kandr-secrets.sh ~/.cursor/scripts/
chmod +x ~/.cursor/scripts/kandr-secrets.sh
ln -sf ~/.cursor/scripts/kandr-secrets.sh /opt/homebrew/bin/kandr-secrets
```

The skills complement the installer by documenting:
- what tools are expected / optional
- how to structure Cursor rules vs skills vs hooks
- safe-by-default workflow principles (checklist-first, opt-in upgrades, minimal destructive actions)

Project-specific values — project IDs, bundle IDs, regions, hosting targets, lane names —
never belong in these skills. They go in the consuming repo's `project-context.mdc` and
`kandr-overlay.mdc`.

- `docs/instruction-architecture.md` — **start here.** The four ownership layers, where Kandr
  secrets end versus a client's begin, what each load mechanism costs per request, and the
  separation of state from instruction
- `docs/project-overlay-contract.md` — the section contract for those two files, when to reach
  for a skill versus a subagent, the anti-patterns to avoid, and conflict-resolution rules
- `templates/cursor-rules/` — copyable starting points for both files
- `docs/skills-audit-2026-08.md` — the audit that produced this layering

