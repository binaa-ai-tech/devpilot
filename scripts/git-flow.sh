#!/usr/bin/env bash
# =============================================================================
# git-flow.sh — Git Flow helper
# =============================================================================
# Usage:
#   bash scripts/git-flow.sh <command> [args...]
#
# Commands:
#   feature-start  <ticket|KEY> <description>   Start a feature branch
#                  (a full tracker key — MSK-12, ADO-12, GH-7 — is used as-is)
#   feature-finish                           Push & remind to open PR
#   release-start  [version]                 Start a release branch (default: the
#                                            version develop already carries)
#   release-finish <version>                 Merge, tag, clean up
#   hotfix-start   <ticket> <description>   Start a hotfix branch
#   hotfix-finish  <version>                 Merge, tag, clean up
# =============================================================================
set -euo pipefail

# Load TICKET_PREFIX from project config (set in .devpilot/config.sh)
if [ -f ".devpilot/config.sh" ]; then
  source ".devpilot/config.sh" 2>/dev/null || true
fi
TICKET_PREFIX="${TICKET_PREFIX:-key}"
DEVELOP=$(grep -E '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '"')
DEVELOP="${DEVELOP:-develop}"
[ "$DEVELOP" = "main" ] && DEVELOP="develop"   # trunk-based projects still release from develop if it exists
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${GREEN}[git-flow]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[git-flow]${RESET} $*"; }
error()   { echo -e "${RED}[git-flow] ERROR:${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──${RESET}"; }

require_clean_tree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    error "Working tree is not clean. Commit or stash your changes first."
  fi
}

current_branch() { git branch --show-current; }

# =============================================================================
# feature-start <ticket> <description> [base-branch]
# =============================================================================
feature_start() {
  local ticket="${1:-}"
  local desc="${2:-}"
  [[ -z "$ticket" ]] && error "Usage: feature-start <ticket-number> <description> [base-branch]"
  [[ -z "$desc"   ]] && error "Usage: feature-start <ticket-number> <description> [base-branch]"

  # 3rd arg overrides; otherwise read from project.config.md; fallback to develop
  local base="${3:-}"
  if [ -z "$base" ]; then
    base=$(grep -E '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' || true)
    [ -z "$base" ] && base="develop"
  fi

  local branch
  if [[ "$ticket" =~ ^[A-Za-z][A-Za-z0-9_]*-[0-9]+$ ]]; then
    branch="feature/$(printf '%s' "$ticket" | tr '[:upper:]' '[:lower:]')-${desc}"
  else
    branch="feature/${TICKET_PREFIX}-${ticket}-${desc}"
  fi
  require_clean_tree

  section "Starting feature: $branch"
  info "Switching to $base and pulling latest..."
  git checkout "$base"
  git pull origin "$base"

  info "Creating branch: $branch"
  git checkout -b "$branch"
  info "Branch ready — start coding!"
}

# =============================================================================
# feature-finish
# =============================================================================
feature_finish() {
  local branch
  branch="$(current_branch)"

  [[ "$branch" != feature/* ]] && error "Not on a feature branch (current: $branch)"
  require_clean_tree

  section "Finishing feature: $branch"
  info "Pushing $branch to origin..."
  git push -u origin "$branch"

  echo ""
  warn "Next step — open a Pull Request on GitHub:"
  echo "  bash scripts/open-pr.sh $DEVELOP \"<title>\" \"<body>\"   (GitHub or Azure Repos)"
  echo ""
  info "After the PR is merged, delete the branch:"
  echo "  git branch -d $branch && git push origin --delete $branch"
}

# =============================================================================
# release-start <version>
# =============================================================================
release_start() {
  local version="${1:-}"
  require_clean_tree

  section "Starting release from $DEVELOP"
  git checkout "$DEVELOP"
  git pull origin "$DEVELOP"

  # Every /dp-deliver merge already bumped the version on develop — release that one.
  [[ -z "$version" ]] && version=$(bash "$SCRIPTS_DIR/version.sh" current)
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Invalid version '$version' (want X.Y.Z)"
  git rev-parse -q --verify "refs/tags/v$version" >/dev/null && error "Tag v$version already exists — deliver a change first or pass a higher version."

  local branch="release/${version}"
  info "Creating branch: $branch"
  git checkout -b "$branch"

  if [ "$(bash "$SCRIPTS_DIR/version.sh" current)" != "$version" ]; then
    bash "$SCRIPTS_DIR/version.sh" bump "$version" >/dev/null
    bash "$SCRIPTS_DIR/version.sh" files | xargs git add
    git commit -m "chore(release): set version $version" || true
  fi

  git push -u origin "$branch"
  info "Release branch $branch created and pushed."
  info "Apply only bug fixes and doc updates to this branch."
  info "When ready: bash scripts/git-flow.sh release-finish $version"
}

# =============================================================================
# release-finish <version>
# =============================================================================
release_finish() {
  local version="${1:-}"
  [[ -z "$version" ]] && error "Usage: release-finish <version>  (e.g. 1.0.0)"

  local branch="release/${version}"
  require_clean_tree

  section "Finishing release: $version"

  git fetch origin
  git checkout "$branch" 2>/dev/null || error "Branch $branch not found locally or on origin."

  info "Merging $branch → main..."
  git checkout main
  git pull origin main
  git merge --no-ff "$branch" -m "chore(git): merge $branch into main"

  info "Tagging v$version..."
  git tag -a "v${version}" -m "Release v${version}"

  info "Merging $branch → $DEVELOP..."
  git checkout "$DEVELOP"
  git pull origin "$DEVELOP"
  git merge --no-ff "$branch" -m "chore(git): merge $branch back into $DEVELOP"

  info "Pushing main, $DEVELOP, and tag..."
  git push origin main "$DEVELOP" "v${version}"

  info "Deleting release branch..."
  git branch -d "$branch"
  git push origin --delete "$branch" 2>/dev/null || warn "Remote branch already deleted."

  section "Release v$version complete"
  info "main and develop are both up to date."
  info "Tag: v$version"
}

# =============================================================================
# hotfix-start <ticket> <description>
# =============================================================================
hotfix_start() {
  local ticket="${1:-}"
  local desc="${2:-}"
  [[ -z "$ticket" ]] && error "Usage: hotfix-start <ticket-number> <description>"
  [[ -z "$desc"   ]] && error "Usage: hotfix-start <ticket-number> <description>"

  local branch
  if [[ "$ticket" =~ ^[A-Za-z][A-Za-z0-9_]*-[0-9]+$ ]]; then
    branch="hotfix/$(printf '%s' "$ticket" | tr '[:upper:]' '[:lower:]')-${desc}"
  else
    branch="hotfix/${TICKET_PREFIX}-${ticket}-${desc}"
  fi
  require_clean_tree

  section "Starting hotfix: $branch"
  info "Switching to main and pulling latest..."
  git checkout main
  git pull origin main

  info "Creating branch: $branch"
  git checkout -b "$branch"
  info "Hotfix branch ready — apply the minimal fix, then:"
  info "  bash scripts/git-flow.sh hotfix-finish <version>"
}

# =============================================================================
# hotfix-finish <version>
# =============================================================================
hotfix_finish() {
  local version="${1:-}"
  [[ -z "$version" ]] && error "Usage: hotfix-finish <version>  (e.g. 1.0.1)"

  local branch
  branch="$(current_branch)"
  [[ "$branch" != hotfix/* ]] && error "Not on a hotfix branch (current: $branch)"
  require_clean_tree

  section "Finishing hotfix: $branch → v$version"

  info "Merging $branch → main..."
  git checkout main
  git pull origin main
  git merge --no-ff "$branch" -m "chore(git): merge $branch into main"

  info "Tagging v$version..."
  git tag -a "v${version}" -m "Hotfix v${version}"

  info "Merging $branch → $DEVELOP..."
  git checkout "$DEVELOP"
  git pull origin "$DEVELOP"
  git merge --no-ff "$branch" -m "chore(git): merge $branch back into $DEVELOP"

  info "Pushing main, $DEVELOP, and tag..."
  git push origin main "$DEVELOP" "v${version}"

  info "Deleting hotfix branch..."
  git branch -d "$branch"
  git push origin --delete "$branch" 2>/dev/null || warn "Remote branch already deleted."

  section "Hotfix v$version complete"
  info "main and develop are both up to date."
  info "Tag: v$version"
}

# =============================================================================
# Dispatch
# =============================================================================
command="${1:-}"
shift || true

case "$command" in
  feature-start)  feature_start  "$@" ;;
  feature-finish) feature_finish "$@" ;;
  release-start)  release_start  "$@" ;;
  release-finish) release_finish "$@" ;;
  hotfix-start)   hotfix_start   "$@" ;;
  hotfix-finish)  hotfix_finish  "$@" ;;
  *)
    echo ""
    echo -e "${BOLD}git-flow.sh — available commands${RESET}"
    echo ""
    echo "  TICKET_PREFIX is '${TICKET_PREFIX}' (set in .devpilot/config.sh)"
    echo ""
    echo "  feature-start  <ticket> <description>   Create feature/${TICKET_PREFIX}-{ticket}-{description}"
    echo "  feature-finish                           Push branch + print PR link"
    echo "  release-start  [version]                 Create release/{version} (default: develop's version)"
    echo "  release-finish <version>                 Merge to main+develop, tag, delete branch"
    echo "  hotfix-start   <ticket> <description>   Create hotfix/${TICKET_PREFIX}-{ticket}-{description}"
    echo "  hotfix-finish  <version>                 Merge to main+develop, tag, delete branch"
    echo ""
    echo "Examples:"
    echo "  bash scripts/git-flow.sh feature-start 12 user-search"
    echo "  bash scripts/git-flow.sh release-start 1.0.0"
    echo "  bash scripts/git-flow.sh hotfix-start 99 fix-login-crash"
    echo ""
    exit 1
    ;;
esac
