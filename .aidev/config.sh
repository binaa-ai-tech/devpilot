#!/bin/bash
# =============================================================================
# PROJECT CONFIG — fill this in once per project, then keep it out of git
# (.aidev/config.sh is gitignored by the installer)
# =============================================================================

# ── Jira ─────────────────────────────────────────────────────────────────────
JIRA_BASE_URL="https://YOUR-ORG.atlassian.net"
JIRA_EMAIL="your-email@example.com"
JIRA_API_TOKEN="YOUR_JIRA_API_TOKEN"
JIRA_PROJECT_KEY="XXX"        # e.g. MSK, NSP, RAF

# ── Git / GitHub ──────────────────────────────────────────────────────────────
GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"
TICKET_PREFIX="mas"            # used in branch names: feature/mas-12-slug

# ── Branches (do not change unless you know what you're doing) ───────────────
MAIN_BRANCH="main"
DEVELOP_BRANCH="develop"

# ── Environment URLs (update after each env is provisioned) ──────────────────
DEV_FRONTEND_URL="https://your-app-dev.onrender.com"
DEV_API_URL="https://your-api-dev.onrender.com"

SIT_FRONTEND_URL="https://your-app-sit.onrender.com"
SIT_API_URL="https://your-api-sit.onrender.com"

UAT_FRONTEND_URL="https://your-app-uat.azurewebsites.net"
UAT_API_URL="https://your-api-uat.azurewebsites.net"

PRD_FRONTEND_URL="https://your-app.com"
PRD_API_URL="https://your-api.azurewebsites.net"

# ── Notifications ─────────────────────────────────────────────────────────────
NOTIFY_EMAIL="your-email@example.com"

# ── AI model for implementation (opencode) ────────────────────────────────────
OPENCODE_MODEL="github-copilot/gpt-5.3-codex"
