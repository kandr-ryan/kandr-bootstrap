#!/usr/bin/env bash
# Point ~/.cursor/{rules,skills,scripts} at this repo's global/ directory.
#
# Idempotent. Never destroys an existing directory — it is moved to a timestamped
# backup and the path is printed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/global"
DEST="$HOME/.cursor"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.cursor-backups/pre-link-$STAMP"

[[ -d "$SRC" ]] || { echo "ERROR: $SRC not found" >&2; exit 1; }
mkdir -p "$DEST"

for name in rules skills scripts; do
  target="$SRC/$name"
  link="$DEST/$name"

  [[ -d "$target" ]] || { echo "skip   $name (not in repo)"; continue; }

  if [[ -L "$link" ]]; then
    current="$(readlink "$link")"
    if [[ "$current" == "$target" ]]; then
      echo "ok     $name (already linked)"
      continue
    fi
    echo "relink $name (was -> $current)"
    rm "$link"
  elif [[ -e "$link" ]]; then
    mkdir -p "$BACKUP"
    mv "$link" "$BACKUP/$name"
    echo "backup $name -> $BACKUP/$name"
  fi

  ln -s "$target" "$link"
  echo "link   ~/.cursor/$name -> global/$name"
done

chmod +x "$SRC"/scripts/* 2>/dev/null || true

echo
echo "Done. Verify:"
echo "  ls ~/.cursor/rules/*.mdc"
[[ -d "$BACKUP" ]] && echo "Prior config backed up at: $BACKUP"
exit 0
