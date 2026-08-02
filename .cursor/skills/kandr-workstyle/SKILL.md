---
name: ryan-workstyle-bootstrap
description: Encodes a pragmatic Cursor/Claude workstyle with checklists, safety constraints, and a macOS bootstrap script for installing core dev CLIs (Homebrew, git, gh, node, firebase, gcloud, jq) plus optional bundles (docker, iOS tooling like fastlane/cocoapods/xcodegen, and integrations like Stripe CLI, Linear CLI, and Claude Code). Use when setting up a new machine, bootstrapping a repo, or when the user mentions Cursor setup, Claude Code, toolchain, bootstrap, Homebrew, Firebase, gcloud, Stripe, Linear, fastlane, or iOS deploy.
---

# Ryan workstyle + bootstrap

This skill is a **shareable, generic** “how I work” setup intended to make a new machine or new repo feel ready-to-go without rediscovering conventions.

## Core principles

- **Checklist-first**: produce a short checklist before doing multi-step work.
- **Safe-by-default**:
  - never upgrade tooling unless explicitly opted in
  - never modify shell profiles automatically
  - never do destructive credential/config operations without explicit approval
- **Progressive disclosure**: keep this file short; refer to reference docs for details.

## How this skill is meant to be used

This repo intentionally splits “ways of working” into **multiple operational skills** so Cursor can apply the right playbook:

- `ryan-workstyle-bootstrap` (this skill): entrypoint + overall defaults.
- `ryan-changelog-release`: changelog + release discipline.
- `ryan-ios-fastlane`: iOS release workflow (Fastlane/XcodeGen/CocoaPods).
- `ryan-architect-mode`: how to use an architect agent before implementation.
- `ryan-ops-loop`: ongoing operational loop (triage → fix → verify → ship).

If a user request matches one of those areas, prefer the specialized skill.

## Quick start (new machine)

1. Run the bootstrap script (interactive defaults are safe):

```bash
curl -fsSL https://raw.githubusercontent.com/kandr-ryan/kandr-bootstrap/main/install.sh | bash
```

2. Optional: run auth flows (script can prompt for these):
   - `gh auth login`
   - `gcloud auth login` and optionally `gcloud auth application-default login`
   - `firebase login`

3. Optional: install iOS toolchain bundle (Fastlane/CocoaPods/XcodeGen) if you ship iOS.

## Quick start (clone-to-productive)

After you’ve cloned a repo and installed tooling, the “default next actions” are:

- Create/verify `.cursor/rules/project-context.mdc` (identifiers + architecture)
- Create/verify `.cursor/rules/local-toolchain.mdc` (safety + tool expectations)
- Start a `CHANGELOG.md` early (see `ryan-changelog-release`)

## Quick start (new repo)

Use this decision rule:
- **Rule** (`.cursor/rules/*.mdc`): persistent project standards and safety constraints.
- **Skill** (`.cursor/skills/<name>/SKILL.md`): repeatable workflow playbooks and “how to do X” procedures.
- **Hook** (`.cursor/hooks.json` + scripts): automated gating/auditing around agent events (optional).

Recommended baseline project rules:
- `project-context.mdc`: identifiers, architecture, roles, env assumptions
- `local-toolchain.mdc` (or equivalent): tool inventory + environment safety constraints

## Tooling map (what to use when)

See [reference/tooling.md](reference/tooling.md) for details; high level defaults:

- **Homebrew**: primary installer on macOS
- **git + gh**: all repo operations; prefer `gh` for GitHub tasks
- **node + npm**: JS/TS runtimes and CLIs
- **firebase**: emulator + deploy workflows (use project-local scripts where possible)
- **gcloud**: Secret Manager, auth, infra glue
- **jq**: scripting JSON safely in shell
- **docker** (optional): local infra/services; prefer Docker Desktop on macOS

iOS bundle (optional):
- Xcode (manual install)
- Homebrew Ruby + Bundler
- Fastlane
- CocoaPods
- XcodeGen

Integrations (optional):
- **Stripe**: use Stripe MCP in-editor when possible; Stripe CLI is optional for webhook/dev workflows.
- **Linear**: use Linear UI or MCP; Linear CLI is optional if you want terminal issue workflows.
- **Claude Code**: optional terminal agent that complements Cursor.

## Agent workflow (how to work with Cursor/Claude)

When the user asks to do work:
- **Clarify** only the minimum (1–2 critical questions).
- **Prefer structured inputs** (multi-choice) when options materially change approach.
- **For multi-step work**: keep a short task list and update statuses.
- **After edits**: run targeted verification (lint/tests) for the touched area.

## “Reference my existing skills/projects” (optional, local-only)

If the user has an existing `~/Apps/` workspace with prior projects and personal skills, use it as a source of truth:

- Look for existing `.cursor/skills/**/SKILL.md` and `.cursor/rules/**/*.mdc` patterns in prior repos.
- Prefer copying/adapting proven workflows rather than inventing new ones.

This repo stays shareable, so it doesn’t assume those paths exist — it describes the *process*.

## Bootstrap script interface

The script supports:
- interactive bundle selection (core / integrations / docker / auth / ios / extras)
- skip-anything behavior
- “install missing only” default
- explicit `--upgrade` to upgrade installed tools
- `--dry-run` to print actions without executing

See [reference/bootstrap-script.md](reference/bootstrap-script.md).

## Reference docs

- [reference/tooling.md](reference/tooling.md)
- [reference/cursor-setup.md](reference/cursor-setup.md)
- [reference/project-templates.md](reference/project-templates.md)
- [reference/bootstrap-script.md](reference/bootstrap-script.md)

