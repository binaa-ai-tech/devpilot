#!/usr/bin/env bash
# =============================================================================
# git-host.sh — where the code lives, so PR automation picks the right API.
#
#   bash scripts/git-host.sh          → github | azure | other
#   bash scripts/git-host.sh check    → also verifies PR automation can run
#
# project.config.md → git_host: auto (default, from the origin remote) | github | azure
#   github → gh CLI, or the GitHub MCP tools where gh is missing (Claude Code on the web)
#   azure  → scripts/azdo.sh (Azure Repos REST, AZDO_PAT)
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"

host() {
  local h; h=$(dp_cfg git_host)
  case "$h" in github|azure) echo "$h"; return ;; esac
  case "$(dp_remote_url)" in
    *github.com*)                         echo "github" ;;
    *dev.azure.com*|*visualstudio.com*)   echo "azure" ;;
    *)                                    echo "other" ;;
  esac
}

H=$(host)
[ "${1:-}" != "check" ] && { echo "$H"; exit 0; }

case "$H" in
  github)
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      echo "✅ git host: GitHub — PRs via gh"
    else
      echo "⚠️  git host: GitHub — gh missing/unauthenticated; PRs go through the GitHub MCP tools (Claude Code on the web) or run: gh auth login"
      exit 1
    fi ;;
  azure)
    dp_load_secrets
    if [ -n "$AZDO_PAT" ]; then echo "✅ git host: Azure Repos — PRs via scripts/azdo.sh"
    else
      echo "⚠️  git host: Azure Repos — set a PAT (Code R/W, Build Read): bash scripts/devpilot-config.sh set azdo_pat=<token>"
      exit 1
    fi ;;
  *) echo "⚠️  git host: unknown remote — PRs must be opened by hand (set git_host: github|azure)"; exit 1 ;;
esac
