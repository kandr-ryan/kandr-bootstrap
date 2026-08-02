#!/usr/bin/env bash
#
# kandr-secrets — resolve Kandr secrets from GCP Secret Manager.
#
# Secrets are never stored in the repo. This reads a per-repo manifest
# (.kandr-secrets) that maps env var names to the GCP project holding them,
# then fetches values on demand using your existing gcloud login.
#
#   kandr-secrets load                  eval-able export statements
#   kandr-secrets env [path]            write a gitignored env file
#   kandr-secrets get NAME              one value to stdout
#   kandr-secrets list                  show the resolved manifest
#   kandr-secrets doctor                verify every entry resolves
#   kandr-secrets clear-cache           drop cached values
#
# Flags: --group NAME (limit to one manifest group), --no-cache
#
# Manifest format (.kandr-secrets at the repo root):
#
#   # comments and blank lines are ignored
#   STRIPE_SECRET_KEY=streamingapp-32dcb
#   AWS_ACCESS_KEY_ID=streamingapp-32dcb:aws-access-key
#
#   [fastlane]
#   MATCH_PASSWORD=streamingapp-32dcb
#
# The second form renames: the local env var is AWS_ACCESS_KEY_ID, the remote
# secret is named aws-access-key. A [group] header scopes the entries beneath
# it, so `--group fastlane` fetches only what a lane needs.

set -euo pipefail

CACHE_DIR="${KANDR_SECRETS_CACHE_DIR:-$HOME/.cache/kandr-secrets}"
CACHE_TTL="${KANDR_SECRETS_TTL:-900}"
MANIFEST_NAME=".kandr-secrets"
USE_CACHE=1
GROUP_FILTER=""

die() { printf 'kandr-secrets: %s\n' "$1" >&2; exit 1; }
note() { printf 'kandr-secrets: %s\n' "$1" >&2; }

# Walk up from $PWD looking for the manifest so the command works from any
# subdirectory of a repo.
find_manifest() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/$MANIFEST_NAME" ] && { printf '%s' "$dir/$MANIFEST_NAME"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

# Emits "VAR<TAB>PROJECT<TAB>REMOTE" per entry, honouring GROUP_FILTER.
read_manifest() {
  local file="$1" line var rhs project remote group=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in
      \[*\]) group="${line#[}"; group="${group%]}"; continue ;;
    esac
    [ -n "$GROUP_FILTER" ] && [ "$group" != "$GROUP_FILTER" ] && continue
    case "$line" in *=*) ;; *) note "skipping malformed line: $line"; continue ;; esac
    var="${line%%=*}"
    rhs="${line#*=}"
    case "$rhs" in
      *:*) project="${rhs%%:*}"; remote="${rhs#*:}" ;;
      *)   project="$rhs";       remote="$var" ;;
    esac
    printf '%s\t%s\t%s\n' "$var" "$project" "$remote"
  done < "$file"
}

cache_path() {
  printf '%s/%s__%s' "$CACHE_DIR" "$1" "$2"
}

cache_fresh() {
  local f="$1" age now mtime
  [ -f "$f" ] || return 1
  now="$(date +%s)"
  mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)"
  age=$(( now - mtime ))
  [ "$age" -lt "$CACHE_TTL" ]
}

# Fetch one secret, using the cache when warm. Values are stored without a
# trailing newline; Match and Fastlane fail cryptically on trailing whitespace.
fetch_secret() {
  local project="$1" remote="$2" cf value
  cf="$(cache_path "$project" "$remote")"
  if [ "$USE_CACHE" -eq 1 ] && cache_fresh "$cf"; then
    cat "$cf"
    return 0
  fi
  value="$(gcloud secrets versions access latest --secret="$remote" --project="$project" 2>/dev/null)" || return 1
  [ -n "$value" ] || return 1
  value="${value%$'\n'}"
  mkdir -p "$CACHE_DIR"; chmod 700 "$CACHE_DIR"
  printf '%s' "$value" > "$cf"; chmod 600 "$cf"
  printf '%s' "$value"
}

# Fetch every manifest entry in parallel, then emit "VAR<TAB>BASE64" lines.
# Sequential fetches cost ~300ms each; a 10-secret repo would otherwise stall
# for 3 seconds on every invocation. Values are base64-encoded for transport
# because PEM private keys contain newlines that would otherwise be read as
# separate records.
fetch_all() {
  local manifest="$1" tmp var project remote pid
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  local pids=""
  while IFS=$'\t' read -r var project remote; do
    (
      if value="$(fetch_secret "$project" "$remote")"; then
        printf '%s' "$value" > "$tmp/$var.val"
      else
        printf '%s\t%s' "$project" "$remote" > "$tmp/$var.err"
      fi
    ) &
    pids="$pids $!"
  done < <(read_manifest "$manifest")
  for pid in $pids; do wait "$pid" || true; done

  local failed=0
  while IFS=$'\t' read -r var project remote; do
    if [ -f "$tmp/$var.val" ]; then
      printf '%s\t%s\n' "$var" "$(base64 < "$tmp/$var.val" | tr -d '\n')"
    else
      note "FAILED $var (secret '$remote' in project '$project')"
      failed=1
    fi
  done < <(read_manifest "$manifest")
  return "$failed"
}

decode() { printf '%s' "$1" | base64 --decode; }

require_manifest() {
  local m
  m="$(find_manifest)" || die "no $MANIFEST_NAME found in $PWD or any parent directory"
  printf '%s' "$m"
}

# Refuse to write an env file that git would track.
assert_ignored() {
  local target="$1"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  if ! git check-ignore -q "$target" 2>/dev/null; then
    die "$target is not gitignored — add it to .gitignore before writing secrets there"
  fi
}

# Single-quote for shell, escaping any embedded single quotes.
shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Render a value for a dotenv file. Multi-line values (PEM private keys, most
# notably) must be double-quoted with escaped newlines, or the file parses as a
# handful of garbage keys. Both Ruby and Node dotenv expand \n inside double
# quotes, so Fastlane and Vite read the same file correctly.
dotenv_quote() {
  local v="$1"
  case "$v" in
    *$'\n'*|*'"'*|*'\'*|' '*|*' ')
      v="${v//\\/\\\\}"
      v="${v//\"/\\\"}"
      v="${v//$'\n'/\\n}"
      printf '"%s"' "$v"
      ;;
    *) printf '%s' "$v" ;;
  esac
}

cmd_load() {
  local manifest var b64
  manifest="$(require_manifest)"
  while IFS=$'\t' read -r var b64; do
    printf 'export %s=%s\n' "$var" "$(shell_quote "$(decode "$b64")")"
  done < <(fetch_all "$manifest")
}

cmd_env() {
  local target="${1:-.env.local}" manifest var b64 tmp count=0
  manifest="$(require_manifest)"
  assert_ignored "$target"
  tmp="$(mktemp)"
  {
    printf '# Generated by kandr-secrets on %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '# Source of truth is GCP Secret Manager. Do not edit or commit.\n'
    while IFS=$'\t' read -r var b64; do
      printf '%s=%s\n' "$var" "$(dotenv_quote "$(decode "$b64")")"
      count=$((count + 1))
    done < <(fetch_all "$manifest")
  } > "$tmp"
  count=$(( $(grep -c '^[A-Za-z_]' "$tmp") ))
  mkdir -p "$(dirname "$target")"
  mv "$tmp" "$target"
  chmod 600 "$target"
  note "wrote $target ($count secrets)"
}

cmd_get() {
  local name="${1:-}" manifest var project remote
  [ -n "$name" ] || die "usage: kandr-secrets get NAME"
  manifest="$(require_manifest)"
  while IFS=$'\t' read -r var project remote; do
    if [ "$var" = "$name" ]; then
      fetch_secret "$project" "$remote" || die "could not read '$remote' from project '$project'"
      return 0
    fi
  done < <(read_manifest "$manifest")
  die "'$name' is not in $manifest"
}

cmd_list() {
  local manifest var project remote
  manifest="$(require_manifest)"
  printf 'Manifest: %s\n\n' "$manifest"
  printf '%-34s %-24s %s\n' "ENV VAR" "GCP PROJECT" "SECRET NAME"
  while IFS=$'\t' read -r var project remote; do
    printf '%-34s %-24s %s\n' "$var" "$project" "$remote"
  done < <(read_manifest "$manifest")
}

cmd_doctor() {
  local manifest var project remote value status=0
  manifest="$(require_manifest)"
  printf 'Checking %s\n\n' "$manifest"
  while IFS=$'\t' read -r var project remote; do
    if value="$(USE_CACHE=0 fetch_secret "$project" "$remote")"; then
      case "$value" in
        # An intentional kill switch, not a gap — report it but do not fail.
        disabled|DISABLED)
          printf '  %-34s disabled on purpose (%s)\n' "$var" "$project" ;;
        [Pp]laceholder*|PLACEHOLDER*|CHANGE_ME*|TODO*|REPLACE_ME*)
          printf '  %-34s PLACEHOLDER VALUE in %s\n' "$var" "$project"; status=1 ;;
        *)
          printf '  %-34s ok (%s chars, %s)\n' "$var" "${#value}" "$project" ;;
      esac
    else
      printf '  %-34s MISSING: no secret %s in %s\n' "$var" "$remote" "$project"; status=1
    fi
  done < <(read_manifest "$manifest")
  [ "$status" -eq 0 ] && printf '\nAll secrets resolve.\n' || printf '\nSome secrets need attention.\n'
  return "$status"
}

cmd_clear_cache() {
  rm -rf "$CACHE_DIR"
  note "cache cleared"
}

usage() {
  sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'
}

main() {
  local args=() expect_group=0
  for a in "$@"; do
    if [ "$expect_group" -eq 1 ]; then GROUP_FILTER="$a"; expect_group=0; continue; fi
    case "$a" in
      --no-cache) USE_CACHE=0 ;;
      --group)    expect_group=1 ;;
      --group=*)  GROUP_FILTER="${a#--group=}" ;;
      *) args+=("$a") ;;
    esac
  done
  [ "$expect_group" -eq 1 ] && die "--group needs a value"
  set -- ${args[@]+"${args[@]}"}
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    load)        cmd_load "$@" ;;
    env)         cmd_env "$@" ;;
    get)         cmd_get "$@" ;;
    list)        cmd_list "$@" ;;
    doctor)      cmd_doctor "$@" ;;
    clear-cache) cmd_clear_cache "$@" ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown command '$cmd' (try --help)" ;;
  esac
}

main "$@"
