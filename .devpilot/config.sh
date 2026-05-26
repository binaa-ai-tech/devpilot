#!/bin/bash
# =============================================================================
# PROJECT CONFIG — fill this in once per project, then keep it out of git
# (.devpilot/config.sh is gitignored by the installer)
#
# Update any key via CLI (recommended — no manual editing needed):
#   bash scripts/devpilot-config.sh set jira_api_token=<new-token>
#   bash scripts/devpilot-config.sh validate
# =============================================================================

# ── Jira ─────────────────────────────────────────────────────────────────────
JIRA_BASE_URL="https://YOUR-ORG.atlassian.net"
JIRA_EMAIL="your-email@example.com"
JIRA_API_TOKEN='YOUR_JIRA_API_TOKEN'
JIRA_PROJECT_KEY="KEY"        # e.g. MSK, APP, PRJ

# ── Git / GitHub ──────────────────────────────────────────────────────────────
GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"
TICKET_PREFIX="key"           # project abbreviation, used in branch names: feature/key-12-slug
                               # e.g. msk, app, prj — should match your Jira project key (lowercase)

# ── Branches ──────────────────────────────────────────────────────────────────
MAIN_BRANCH="main"
DEVELOP_BRANCH="develop"

# ── Environment URLs (update after each env is provisioned) ──────────────────
# Leave blank if an environment is not used in this project.
DEV_FRONTEND_URL=""
DEV_API_URL=""

SIT_FRONTEND_URL=""
SIT_API_URL=""

UAT_FRONTEND_URL=""
UAT_API_URL=""

PRD_FRONTEND_URL=""
PRD_API_URL=""

# ── Notifications ─────────────────────────────────────────────────────────────
NOTIFY_EMAIL="your-email@example.com"
DEVPILOT_CONFIG_UPDATED_AT='2026-05-26T13:40:31Z'
