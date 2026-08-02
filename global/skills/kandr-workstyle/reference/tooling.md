## Tooling reference (macOS)

This document explains the “default toolchain” assumptions used by the bootstrap script and this skill.

### Install philosophy

- **Prefer Homebrew** for macOS packages.
- **Do not auto-upgrade** existing tools unless the user explicitly requests upgrades.
- **Do not edit shell profiles** automatically. If PATH changes are needed, print instructions.

### Core tools (recommended)

- **Homebrew** (`brew`)
  - Purpose: package manager for macOS.
- **Git** (`git`)
  - Purpose: source control.
- **GitHub CLI** (`gh`)
  - Purpose: repo creation, PRs, issues, releases, auth.
- **Node.js / npm** (`node`, `npm`)
  - Purpose: JS/TS runtime and CLIs.
- **Firebase CLI** (`firebase`)
  - Purpose: emulators, deploy, project ops.
  - Install method (recommended here): `npm install -g firebase-tools` to track upstream releases.
- **Google Cloud SDK** (`gcloud`)
  - Purpose: Secret Manager, IAM, auth, infra helpers.
- **jq**
  - Purpose: robust JSON parsing/manipulation in scripts.

### Optional tools

- **Docker Desktop** (`docker`)
  - Purpose: local containers and dev services.
- **ripgrep** (`rg`)
  - Purpose: fast local searching (often already available in dev setups).
- **Stripe CLI** (`stripe`)
  - Purpose: webhook testing, local Stripe workflows.
- **Claude Code** (`claude`)
  - Purpose: terminal-based coding agent; complements Cursor workflows.
- **Linear CLI** (`linear`)
  - Purpose: issue management from terminal (optional; not required if using Linear via UI/MCP).

### iOS bundle (optional)

Some iOS tooling cannot be fully automated safely.

- **Xcode**: install via the Mac App Store, then run:

```bash
sudo xcodebuild -license accept
sudo xcode-select --switch /Applications/Xcode.app
```

- **Ruby (Homebrew)** + **Bundler**:
  - Used for Fastlane and CocoaPods.
  - This setup avoids macOS system Ruby.
- **Fastlane** (`fastlane`)
  - Purpose: TestFlight/App Store workflows.
- **CocoaPods** (`pod`)
  - Purpose: iOS dependency management.
- **XcodeGen** (`xcodegen`)
  - Purpose: generate Xcode projects from `project.yml`.

### Authentication flows (optional prompts)

- GitHub: `gh auth login`
- Google Cloud:
  - `gcloud auth login` (CLI user auth)
  - `gcloud auth application-default login` (ADC used by SDKs/tools)
- Firebase: `firebase login`

### Cursor integrations (MCP)

If you use Cursor’s MCP plugins (e.g. Stripe + Linear), the “installation” is usually **auth inside Cursor**, not a system CLI.
Keep CLI installs optional; prefer MCP for in-editor workflows.

