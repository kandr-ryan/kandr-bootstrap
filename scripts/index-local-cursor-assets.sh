#!/usr/bin/env bash
set -euo pipefail

# Local-only helper:
# Inventories Cursor skills/rules across a developer's machine so an agent (or human)
# can reference existing workflows without hard-coding any repo-specific assumptions
# into a shared/public bootstrap repo.

ROOT_APPS="${1:-$HOME/Apps}"

say() { printf "%s\n" "$*"; }

if [[ ! -d "$ROOT_APPS" ]]; then
  say "Apps directory not found: $ROOT_APPS"
  say "Usage: $0 [apps_root]"
  exit 1
fi

say "Cursor asset inventory"
say "- apps_root: $ROOT_APPS"
say "- generated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
say ""

say "== Personal skills (if present) =="
if [[ -d "$HOME/.cursor/skills" ]]; then
  find "$HOME/.cursor/skills" -maxdepth 2 -name "SKILL.md" -print | sort || true
else
  say "(none found at $HOME/.cursor/skills)"
fi
say ""

say "== Project skills under ~/Apps/* (if present) =="
find "$ROOT_APPS" -maxdepth 6 -path "*/.cursor/skills/*/SKILL.md" -print 2>/dev/null | sort || true
say ""

say "== Project rules under ~/Apps/* (if present) =="
find "$ROOT_APPS" -maxdepth 6 -path "*/.cursor/rules/*.mdc" -print 2>/dev/null | sort || true
say ""

say "== Project hooks under ~/Apps/* (if present) =="
find "$ROOT_APPS" -maxdepth 5 -path "*/.cursor/hooks.json" -print 2>/dev/null | sort || true
say ""

say "Done."

