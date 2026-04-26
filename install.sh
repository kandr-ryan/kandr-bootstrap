#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

WITH_CORE=1
WITH_INTEGRATIONS=0
WITH_DOCKER=0
WITH_IOS=0
WITH_EXTRAS=0
WITH_AUTH=0

NON_INTERACTIVE=0
DRY_RUN=0
DO_UPGRADE=0

usage() {
  cat <<'EOF'
macOS bootstrap installer.

Safe defaults:
- installs missing tools only
- does NOT upgrade unless --upgrade is provided
- does NOT modify shell profiles

Usage:
  install.sh [options]

Options:
  --non-interactive         Do not prompt. Use explicit --with-* / --skip-* flags.
  --dry-run                 Print actions without executing them.
  --upgrade                 Upgrade installed tools (brew/npm/gem) where applicable.

  --with-core | --skip-core
  --with-integrations | --skip-integrations
  --with-docker | --skip-docker
  --with-ios | --skip-ios
  --with-extras | --skip-extras
  --with-auth | --skip-auth

Examples:
  ./install.sh
  ./install.sh --with-core --with-auth
  ./install.sh --with-core --with-integrations
  ./install.sh --with-core --with-ios --upgrade
  ./install.sh --non-interactive --with-core --skip-auth --dry-run
EOF
}

log()  { printf "%s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }
die()  { printf "ERROR: %s\n" "$*" >&2; exit 1; }

is_tty() { [[ -t 0 && -t 1 ]]; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-N}" # Y or N

  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    [[ "$default" == "Y" ]] && return 0 || return 1
  fi

  local suffix
  if [[ "$default" == "Y" ]]; then suffix="Y/n"; else suffix="y/N"; fi

  while true; do
    printf "%s [%s] " "$prompt" "$suffix" >&2
    local ans=""
    IFS= read -r ans
    ans="${ans:-$default}"
    case "$ans" in
      Y|y) return 0 ;;
      N|n) return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
  done
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script currently supports macOS only."
  fi
}

install_homebrew() {
  if have_cmd brew; then
    log "- Homebrew: already installed"
    return 0
  fi

  log "- Homebrew: installing"
  run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! have_cmd brew; then
    warn "Homebrew installed but not on PATH in this shell."
    warn "Restart your terminal, then re-run this script."
    die "brew not found after install"
  fi
}

brew_install_formula() {
  local formula="$1"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    log "- $formula: already installed"
    if [[ "$DO_UPGRADE" == "1" ]]; then
      log "  upgrading $formula"
      run brew upgrade "$formula" || true
    fi
    return 0
  fi
  log "- $formula: installing"
  run brew install "$formula"
}

brew_install_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log "- $cask: already installed (cask)"
    if [[ "$DO_UPGRADE" == "1" ]]; then
      log "  upgrading $cask (cask)"
      run brew upgrade --cask "$cask" || true
    fi
    return 0
  fi
  log "- $cask: installing (cask)"
  run brew install --cask "$cask"
}

npm_install_global() {
  local pkg="$1"
  if ! have_cmd npm; then
    die "npm not found. Install Node first (core bundle)."
  fi

  if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
    log "- npm:$pkg: already installed"
    if [[ "$DO_UPGRADE" == "1" ]]; then
      log "  upgrading npm:$pkg"
      run npm update -g "$pkg" || true
    fi
    return 0
  fi

  log "- npm:$pkg: installing"
  run npm install -g "$pkg"
}

brew_ruby_prefix() {
  brew --prefix ruby 2>/dev/null || true
}

gem_bin() {
  local prefix
  prefix="$(brew_ruby_prefix)"
  if [[ -n "$prefix" && -x "$prefix/bin/gem" ]]; then
    printf "%s" "$prefix/bin/gem"
    return 0
  fi
  printf "%s" "gem"
}

gem_install_or_upgrade() {
  local gem_name="$1"
  local gem_exec
  gem_exec="$(gem_bin)"

  if "$gem_exec" list -i "$gem_name" >/dev/null 2>&1; then
    log "- gem:$gem_name: already installed"
    if [[ "$DO_UPGRADE" == "1" ]]; then
      log "  upgrading gem:$gem_name"
      run "$gem_exec" update "$gem_name" || true
    fi
    return 0
  fi

  log "- gem:$gem_name: installing"
  run "$gem_exec" install "$gem_name"
}

interactive_select_bundles() {
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    return 0
  fi
  if ! is_tty; then
    warn "Not running in an interactive TTY; switching to non-interactive mode."
    NON_INTERACTIVE=1
    return 0
  fi

  log "Bundle selection (safe defaults):"
  if prompt_yes_no "Install core dev tools (brew, git, gh, node, jq, gcloud, firebase)?" "Y"; then
    WITH_CORE=1
  else
    WITH_CORE=0
  fi

  if prompt_yes_no "Install integrations bundle (Stripe CLI, Linear CLI, Claude Code)?" "N"; then
    WITH_INTEGRATIONS=1
  else
    WITH_INTEGRATIONS=0
  fi

  if prompt_yes_no "Install Docker Desktop?" "N"; then
    WITH_DOCKER=1
  else
    WITH_DOCKER=0
  fi

  if prompt_yes_no "Install iOS release tooling bundle (ruby/bundler/fastlane/cocoapods/xcodegen)?" "N"; then
    WITH_IOS=1
  else
    WITH_IOS=0
  fi

  if prompt_yes_no "Install extras (ripgrep)?" "N"; then
    WITH_EXTRAS=1
  else
    WITH_EXTRAS=0
  fi

  if prompt_yes_no "Run optional auth flows (gh/gcloud/firebase)?" "N"; then
    WITH_AUTH=1
  else
    WITH_AUTH=0
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --upgrade) DO_UPGRADE=1 ;;

      --with-core) WITH_CORE=1 ;;
      --skip-core) WITH_CORE=0 ;;
      --with-integrations) WITH_INTEGRATIONS=1 ;;
      --skip-integrations) WITH_INTEGRATIONS=0 ;;
      --with-docker) WITH_DOCKER=1 ;;
      --skip-docker) WITH_DOCKER=0 ;;
      --with-ios) WITH_IOS=1 ;;
      --skip-ios) WITH_IOS=0 ;;
      --with-extras) WITH_EXTRAS=1 ;;
      --skip-extras) WITH_EXTRAS=0 ;;
      --with-auth) WITH_AUTH=1 ;;
      --skip-auth) WITH_AUTH=0 ;;

      *) die "Unknown argument: $1" ;;
    esac
    shift
  done
}

install_integrations() {
  log ""
  log "== Integrations =="
  install_homebrew

  brew_install_formula stripe-cli

  # Linear CLI (community maintained).
  if brew list --formula linear-cli >/dev/null 2>&1; then
    log "- linear-cli: already installed"
    if [[ "$DO_UPGRADE" == "1" ]]; then
      log "  upgrading linear-cli"
      run brew upgrade linear-cli || true
    fi
  else
    log "- linear-cli: installing (via tap)"
    run brew tap joa23/linear-cli https://github.com/joa23/linear-cli
    run brew install linear-cli
  fi

  brew_install_cask claude-code
}

install_core() {
  log ""
  log "== Core tools =="

  install_homebrew

  if [[ "$DO_UPGRADE" == "1" ]]; then
    log "- brew: updating"
    run brew update
  fi

  brew_install_formula git
  brew_install_formula gh
  brew_install_formula node
  brew_install_formula jq
  brew_install_formula google-cloud-sdk

  npm_install_global firebase-tools

  log ""
  log "Core notes:"
  log "- This script does not modify shell profiles."
  log "- If gcloud is installed but not found, restart your terminal."
}

install_docker() {
  log ""
  log "== Docker =="
  install_homebrew
  brew_install_cask docker
  log "Docker Desktop installed. Launch it once to finish setup."
}

install_extras() {
  log ""
  log "== Extras =="
  install_homebrew
  brew_install_formula ripgrep
}

install_ios_bundle() {
  log ""
  log "== iOS tooling bundle =="
  install_homebrew

  log "- Xcode: cannot be installed automatically here."
  log "  Install Xcode via the Mac App Store, then run:"
  log "    sudo xcodebuild -license accept"
  log "    sudo xcode-select --switch /Applications/Xcode.app"

  brew_install_formula ruby

  gem_install_or_upgrade bundler
  gem_install_or_upgrade fastlane
  gem_install_or_upgrade cocoapods

  brew_install_formula xcodegen

  log ""
  log "iOS notes:"
  log "- If you need Homebrew Ruby on PATH in new shells, add it manually (do not auto-edit profiles):"
  log "    export PATH=\"$(brew --prefix ruby)/bin:$PATH\""
}

run_auth_flows() {
  log ""
  log "== Optional auth =="

  if have_cmd gh && prompt_yes_no "Run: gh auth login ?" "N"; then
    run gh auth login
  fi

  if have_cmd gcloud && prompt_yes_no "Run: gcloud auth login ?" "N"; then
    run gcloud auth login
  fi

  if have_cmd gcloud && prompt_yes_no "Run: gcloud auth application-default login ? (for SDKs/ADC)" "N"; then
    run gcloud auth application-default login
  fi

  if have_cmd firebase && prompt_yes_no "Run: firebase login ?" "N"; then
    run firebase login
  fi
}

main() {
  require_macos
  parse_args "$@"
  interactive_select_bundles

  log ""
  log "Selections:"
  log "- core:   $([[ "$WITH_CORE" == "1" ]] && echo yes || echo no)"
  log "- integrations: $([[ "$WITH_INTEGRATIONS" == "1" ]] && echo yes || echo no)"
  log "- docker: $([[ "$WITH_DOCKER" == "1" ]] && echo yes || echo no)"
  log "- ios:    $([[ "$WITH_IOS" == "1" ]] && echo yes || echo no)"
  log "- extras: $([[ "$WITH_EXTRAS" == "1" ]] && echo yes || echo no)"
  log "- auth:   $([[ "$WITH_AUTH" == "1" ]] && echo yes || echo no)"
  log "- upgrade: $([[ "$DO_UPGRADE" == "1" ]] && echo yes || echo no)"
  log "- dry-run: $([[ "$DRY_RUN" == "1" ]] && echo yes || echo no)"

  if [[ "$WITH_CORE" == "0" && "$WITH_INTEGRATIONS" == "0" && "$WITH_DOCKER" == "0" && "$WITH_IOS" == "0" && "$WITH_EXTRAS" == "0" && "$WITH_AUTH" == "0" ]]; then
    log ""
    log "Nothing selected. Exiting."
    return 0
  fi

  if [[ "$WITH_CORE" == "1" ]]; then install_core; fi
  if [[ "$WITH_INTEGRATIONS" == "1" ]]; then install_integrations; fi
  if [[ "$WITH_DOCKER" == "1" ]]; then install_docker; fi
  if [[ "$WITH_IOS" == "1" ]]; then install_ios_bundle; fi
  if [[ "$WITH_EXTRAS" == "1" ]]; then install_extras; fi
  if [[ "$WITH_AUTH" == "1" ]]; then run_auth_flows; fi

  log ""
  log "Done."
}

main "$@"

