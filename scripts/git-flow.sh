#!/usr/bin/env bash
# =============================================================================
# git-flow.sh — Git Flow helper
# =============================================================================
# Usage:
#   bash scripts/git-flow.sh <command> [args...]
#
# Commands:
#   feature-start  <ticket> <description>   Start a feature branch
#   feature-finish                           Push & remind to open PR
#   release-start  <version>                 Start a release branch
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

  local branch="feature/${TICKET_PREFIX}-${ticket}-${desc}"
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
  echo "  https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')/compare/develop...${branch}"
  echo ""
  info "After the PR is merged, delete the branch:"
  echo "  git branch -d $branch && git push origin --delete $branch"
}

# =============================================================================
# release-start <version>
# =============================================================================
release_start() {
  local version="${1:-}"
  [[ -z "$version" ]] && error "Usage: release-start <version>  (e.g. 1.0.0)"

  local branch="release/${version}"
  require_clean_tree

  section "Starting release: $branch"
  info "Switching to develop and pulling latest..."
  git checkout develop
  git pull origin develop

  info "Creating branch: $branch"
  git checkout -b "$branch"

  info "Bumping version in package.json to $version..."
  if command -v npm &>/dev/null && [[ -f package.json ]]; then
    npm version "$version" --no-git-tag-version --allow-same-version 2>/dev/null || \
      warn "npm version bump failed — update package.json manually."
    git add package.json package-lock.json 2>/dev/null || true
    git commit -m "chore(git): bump version to $version" || true
  else
    warn "package.json not found — skip version bump."
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

  info "Merging $branch → develop..."
  git checkout develop
  git pull origin develop
  git merge --no-ff "$branch" -m "chore(git): merge $branch back into develop"

  info "Pushing main, develop, and tag..."
  git push origin main develop "v${version}"

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

  local branch="hotfix/${TICKET_PREFIX}-${ticket}-${desc}"
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

  info "Merging $branch → develop..."
  git checkout develop
  git pull origin develop
  git merge --no-ff "$branch" -m "chore(git): merge $branch back into develop"

  info "Pushing main, develop, and tag..."
  git push origin main develop "v${version}"

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
    echo "  release-start  <version>                 Create release/{version}, bump package.json"
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
