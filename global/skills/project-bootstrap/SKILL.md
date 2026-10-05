---
name: project-bootstrap
description: Guides the full setup of a new Kandr app or project — from Firebase provisioning through Fastlane TestFlight uploads. Produces step-by-step checklists based on app type (iOS, web, Cloud Run). Use when starting a new app, bootstrapping a project, or scaffolding infrastructure.
---

<!-- SECRET-AUDIT: the Match password registry below duplicates values that now live in
     GCP Secret Manager as MATCH_PASSWORD on each app's own project:
       streamingapp-32dcb, kandr-radio-app, fishon-kandr-app, yard-sale-3a062
     Keep the naming convention here; the values are redundant and should be dropped.
     Keychain/login passwords are NOT stored anywhere — remove those examples entirely.
     Full workflow: ~/.cursor/skills/kandr-secrets/SKILL.md
-->

# Project Bootstrap Agent

This skill encodes every pattern, convention, and infrastructure decision across Kandr apps (Fish On!, Faith Music Streaming, Kandr Radio, Yard Seller, and others). It produces a complete, sequenced checklist so nothing gets missed when spinning up a new project.

## How This Works

1. Gather requirements interactively (Phase 1)
2. Produce a tailored infrastructure checklist (Phase 2)
3. Show the project structure (Phase 3)
4. Reference detailed config templates on demand (Phase 4 — in `infrastructure-reference.md`)
5. Produce deployment pipeline commands (Phase 5)
6. Generate `.cursor/rules/` files for the new project (Phase 6)

The agent does NOT auto-execute commands or generate files. It produces checklists and the user decides what to run.

### Environment Awareness

All CLI tools needed for Kandr projects are already installed. See `~/.cursor/rules/local-toolchain.mdc` for the full inventory with versions and paths. Do NOT ask the user to install anything, do NOT run version checks, and do NOT guess whether a tool is available — it is documented.

### Environment Safety

If the agent encounters an environment problem (wrong password, expired cert, keychain locked, auth failure, version mismatch), it MUST:
1. Report the exact error
2. Suggest a fix
3. **Ask the user before taking any action**

The agent must NEVER destructively "fix" issues on its own — no deleting certs, no regenerating profiles, no changing passwords, no nuking Match repos, no modifying shell configs. See `~/.cursor/rules/local-toolchain.mdc` for the full list of prohibited actions.
