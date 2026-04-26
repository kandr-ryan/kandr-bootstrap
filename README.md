## kandr-bootstrap

Shareable **macOS bootstrap installer** + a **Cursor Skill** that documents a pragmatic “how I work” setup.

If you want a new machine to be productive quickly (without hand-installing a dozen CLIs, and without risky auto-configuration), this repo gives you:
- a safe-by-default installer (`install.sh`)
- a shareable Cursor Skill (`.cursor/skills/ryan-workstyle-bootstrap/`) that captures workflows + conventions

### Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/kandr-ryan/kandr-bootstrap/main/install.sh | bash
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

### Cursor Skill

This repo includes a shareable Skill under:

- `.cursor/skills/ryan-workstyle-bootstrap/`

Copy that folder into any project repo to share the same skill with collaborators, or keep it in a template repo that new projects start from.

The skill complements the installer by documenting:
- what tools are expected / optional
- how to structure Cursor rules vs skills vs hooks
- safe-by-default workflow principles (checklist-first, opt-in upgrades, minimal destructive actions)

