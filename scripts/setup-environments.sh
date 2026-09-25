#!/usr/bin/env bash
# =============================================================================
# setup-environments.sh — create the dev · sit · uat · prd deployment environments
# the CD pipeline promotes through, with human approval on uat and prd.
#
#   bash scripts/setup-environments.sh
#   DEVPILOT_APPROVERS="alice,bob" bash scripts/setup-environments.sh   # GitHub logins
#   DEVPILOT_APPROVERS="ana@corp.com,[Shop]\Release Managers" …          # Azure users / groups
#
# GitHub      → repo environments (gh, admin rights): uat/prd require reviewers
#               (DEVPILOT_APPROVERS, default: you); deploy branches restricted —
#               dev: develop · sit/uat: release/*, hotfix/* · prd: release/*, hotfix/*, v* tags
# Azure       → Pipelines environments + an Approval check on uat/prd — approvers from
#               DEVPILOT_APPROVERS (emails and/or "[Project]\Group" names; default: you), and the
#               devpilot-cd pipeline from azure-pipelines-cd.yml
# Idempotent; prints the manual steps when it lacks rights. Never fails an install.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
cd "$DP_ROOT" || exit 1
BASE=$(dp_cfg base_branch); BASE="${BASE:-develop}"

case "$(bash "$DIR/git-host.sh")" in
  azure)
    if ! bash "$DIR/azdo.sh" repo-id >/dev/null 2>&1; then
      echo "ℹ️  Azure DevOps not reachable (AZDO_PAT?). Create by hand: Pipelines → Environments → dev, sit, uat, prd;"
      echo "    on uat and prd: ⋯ → Approvals and checks → Approvals. Then create a pipeline from azure-pipelines-cd.yml."
      exit 0
    fi
    for E in dev sit; do bash "$DIR/azdo.sh" env-setup "$E" || true; done
    for E in uat prd; do bash "$DIR/azdo.sh" env-setup "$E" --approval || true; done
    if [ -f azure-pipelines-cd.yml ]; then
      bash "$DIR/azdo.sh" pipeline-ensure devpilot-cd azure-pipelines-cd.yml >/dev/null \
        && echo "  ✅ pipeline devpilot-cd" \
        || echo "  ⚠️  commit azure-pipelines-cd.yml to $BASE, then re-run to create the devpilot-cd pipeline"
    fi
    echo "  Deploy secrets: Pipelines → Library → variable group or pipeline variables DEPLOY_HOOK_<ENV>, <ENV>_API_URL, <ENV>_FRONTEND_URL."
    ;;
  github)
    if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
      echo "ℹ️  gh not authenticated. Create by hand: Settings → Environments → dev, sit, uat, prd;"
      echo "    on uat and prd tick 'Required reviewers'. Or: gh auth login && bash scripts/setup-environments.sh"
      exit 0
    fi
    SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    [ -n "$SLUG" ] || { echo "ℹ️  no GitHub repo detected — skipped"; exit 0; }
    IDS=""
    for L in $(printf '%s' "${DEVPILOT_APPROVERS:-$(gh api user -q .login 2>/dev/null)}" | tr ',' ' '); do
      ID=$(gh api "users/$L" -q .id 2>/dev/null) && IDS="$IDS{\"type\":\"User\",\"id\":$ID},"
    done
    REVIEWERS="[${IDS%,}]"
    for E in dev sit uat prd; do
      case "$E" in
        dev) PATTERNS="$BASE" ;;
        sit|uat) PATTERNS="release/* hotfix/*" ;;
        prd) PATTERNS="release/* hotfix/* tag:v*" ;;
      esac
      BODY='{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
      case "$E" in uat|prd) BODY="{\"reviewers\":$REVIEWERS,\"deployment_branch_policy\":{\"protected_branches\":false,\"custom_branch_policies\":true}}" ;; esac
      if ! printf '%s' "$BODY" | gh api -X PUT "repos/$SLUG/environments/$E" --input - >/dev/null 2>&1; then
        echo "  ⚠️  $E — could not configure (needs admin rights; reviewers need a paid plan on private repos)"; continue
      fi
      for PAT in $PATTERNS; do
        TYPE=branch; NAME="$PAT"; case "$PAT" in tag:*) TYPE=tag; NAME="${PAT#tag:}" ;; esac
        gh api -X POST "repos/$SLUG/environments/$E/deployment-branch-policies" -f name="$NAME" -f type="$TYPE" >/dev/null 2>&1 || true
      done
      case "$E" in uat|prd) echo "  ✅ $E — approval required · deploys from: $PATTERNS" ;; *) echo "  ✅ $E — deploys from: $PATTERNS" ;; esac
    done
    echo "  Deploy secrets per environment: DEPLOY_HOOK (secret) · API_URL / FRONTEND_URL (variables) — or ship deploy/deploy.sh."
    ;;
  *) echo "ℹ️  unknown git host — create dev/sit/uat/prd environments with approvals on uat/prd in your CI system." ;;
esac
exit 0
