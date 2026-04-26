## Bootstrap script spec (macOS)

This is the contract the GitHub-hosted installer script should follow.

### Defaults (safe)

- Installs **missing** tools only.
- Does **not** upgrade installed tools unless `--upgrade` is passed.
- Does **not** modify shell profiles.
- Provides interactive selection with **skipable bundles**.

### Groups

- **core** (default on)
  - Homebrew (install if missing)
  - git
  - gh
  - node
  - jq
  - gcloud
  - firebase (via npm global)
- **integrations** (default off)
  - Stripe CLI (`stripe`)
  - Linear CLI (`linear`) (optional; CLI quality varies by implementation)
  - Claude Code (brew cask; provides `claude`)
- **docker** (default off)
  - Docker Desktop (brew cask)
- **ios** (default off)
  - Xcode (manual instructions)
  - Ruby (brew)
  - Bundler
  - Fastlane
  - CocoaPods
  - XcodeGen
- **extras** (default off)
  - ripgrep

### Flags

- `--non-interactive`
- `--dry-run`
- `--upgrade`
- `--with-core` / `--skip-core`
- `--with-integrations` / `--skip-integrations`
- `--with-docker` / `--skip-docker`
- `--with-ios` / `--skip-ios`
- `--with-extras` / `--skip-extras`
- `--with-auth` / `--skip-auth`

### Auth prompts (optional)

If `--with-auth` is enabled (or interactive selection enables it), offer:
- `gh auth login`
- `gcloud auth login`
- `gcloud auth application-default login`
- `firebase login`

