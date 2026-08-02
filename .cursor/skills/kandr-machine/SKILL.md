---
name: kandr-machine
description: What is installed on this Mac and at which versions — Homebrew Ruby, Bundler, Fastlane, CocoaPods, Xcode, XcodeGen, Swift, Node, npm, Firebase CLI, gcloud, AWS CLI, git, gh, Docker, Python, jq — plus the Homebrew Ruby PATH export required before any Ruby, Fastlane, or Bundler command. Use when a version matters, a tool path is needed, or a command fails in a way that looks like a toolchain or PATH problem.
---

# Local toolchain

These tools are installed. Do not ask the user to install them, do not check whether they exist,
and do not run `which` or `--version` to verify them.

| Tool | Version | Path / Notes |
|---|---|---|
| Homebrew | 5.0.16 | `/opt/homebrew/bin/brew` |
| Ruby | 4.0.1 | `/opt/homebrew/opt/ruby/bin/ruby` (NOT system Ruby 2.6) |
| Bundler | 4.0.6 | `/opt/homebrew/lib/ruby/gems/4.0.0/bin/bundler` |
| Fastlane | 2.232.2 | `/opt/homebrew/lib/ruby/gems/4.0.0/bin/fastlane` (includes match, deliver, pilot, spaceship) |
| CocoaPods | 1.16.2 | `/opt/homebrew/lib/ruby/gems/4.0.0/bin/pod` |
| Xcode | 26.2 (Build 17C52) | `xcodebuild` |
| XcodeGen | 2.44.1 | `/opt/homebrew/bin/xcodegen` |
| Swift | 6.2.3 | via Xcode toolchain |
| Node.js | 25.4.0 | `node` |
| npm | 11.7.0 | `npm` |
| Firebase CLI | 15.5.1 | `firebase` |
| Google Cloud SDK | 553.0.0 | `gcloud` |
| AWS CLI | 2.34.0 | `aws` |
| Git | 2.50.1 | Apple Git |
| GitHub CLI | 2.86.0 | `gh` |
| Docker | 29.2.1 | `docker` |
| Python | 3.9.6 | `python3` (system) |
| jq | 1.7.1 | `jq` |
| curl | 8.7.1 | `curl` |
| security | system | `/usr/bin/security` (keychain management) |
| xcrun simctl | system | iOS Simulator management |

## Ruby PATH

Homebrew Ruby MUST be used instead of system Ruby. Set this before any Ruby, Fastlane, or Bundler
command:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
```

The Homebrew gems directory is `/opt/homebrew/lib/ruby/gems/4.0.0/`. If the version changes, check
with `ls /opt/homebrew/lib/ruby/gems/`.

## When something in the environment breaks

The standing rule is to report, not repair — the specifics are in the router. Do not reinstall,
upgrade, or uninstall a tool, do not modify shell profiles, and do not touch AWS or gcloud auth
config. Instead:

1. Report exactly what went wrong, with the full error message
2. State which tool and version is involved
3. Suggest what the fix might be
4. Ask the user before doing anything
