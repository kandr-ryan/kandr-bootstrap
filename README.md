## kandr-bootstrap

Shareable macOS bootstrap installer + a Cursor Skill that documents a pragmatic “how I work” setup.

### Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/kandr-ryan/kandr-bootstrap/main/install.sh | bash
```

### What it installs

Safe defaults: **installs missing tools only**, upgrades only with `--upgrade`.

- **Core (default on)**: Homebrew, git, gh, node, jq, gcloud, firebase
- **Integrations (optional)**: Stripe CLI, Linear CLI, Claude Code
- **Docker (optional)**: Docker Desktop
- **iOS (optional)**: Homebrew Ruby, bundler, fastlane, cocoapods, xcodegen (Xcode is manual)
- **Extras (optional)**: ripgrep
- **Auth (optional)**: prompts to run `gh auth login`, `gcloud auth login`, `gcloud auth application-default login`, `firebase login`

### Examples

```bash
./install.sh
./install.sh --with-core --with-integrations
./install.sh --with-core --with-ios --upgrade
./install.sh --dry-run
```

### Cursor Skill

This repo includes a shareable Skill under:

- `.cursor/skills/ryan-workstyle-bootstrap/`

Copy that folder into any project repo to share the same skill with collaborators.

