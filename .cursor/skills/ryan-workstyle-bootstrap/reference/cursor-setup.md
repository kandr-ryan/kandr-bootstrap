## Cursor setup conventions

### What goes where

- **Rules**: `.cursor/rules/*.mdc`
  - Persistent project context and standards (architecture, naming, safety, file-specific rules).
- **Skills**: `.cursor/skills/<skill-name>/SKILL.md`
  - Playbooks for repeatable workflows and “how to do X” knowledge.
- **Hooks** (optional): `.cursor/hooks.json` + scripts
  - Automated checks/gates around agent events (shell execution, MCP calls, file edits).

### Rule authoring guidelines

- Keep rules short, focused, and actionable.
- Prefer “defaults + escape hatches” (a recommended way, and when it’s okay to deviate).
- Use file globs for rules that only apply to certain areas (e.g. `functions/**/*.ts`, `src/**/*.tsx`).

### Hook usage (optional)

Use hooks when you want lightweight guardrails like:
- gate risky shell commands (network calls, destructive ops)
- gate MCP calls
- run formatters after file edits

Keep hooks **fail-open** by default unless you intentionally want “fail-closed” safety.

### Recommended baseline setup for a new repo

- Add `.cursor/rules/project-context.mdc` describing:
  - app name, repo URL, deployment targets, runtime versions
  - key data models and collections (if applicable)
  - role model and auth
- Add `.cursor/rules/local-toolchain.mdc` describing:
  - expected local tooling
  - what not to do automatically (credentials, upgrades, destructive resets)

