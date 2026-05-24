# binaa-ai Dev Process

AI-assisted development flow. From idea to production with a full DEV → SIT → UAT → PRD pipeline.

## Install into any project

```bash
curl -s https://raw.githubusercontent.com/binaa-ai-tech/dev-process/main/install.sh | bash
```

## Configure

Edit `.aidev/config.sh` (gitignored — never committed):

```bash
# Jira
JIRA_BASE_URL="https://your-org.atlassian.net"
JIRA_EMAIL="your-email@example.com"
JIRA_API_TOKEN="your-token"
JIRA_PROJECT_KEY="XXX"

# GitHub
GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"
TICKET_PREFIX="xxx"          # used in branch names: feature/xxx-42-slug

# Environment URLs
DEV_FRONTEND_URL="https://your-app-dev.onrender.com"
SIT_FRONTEND_URL="https://your-app-sit.onrender.com"
UAT_FRONTEND_URL="https://your-app-uat.azurewebsites.net"
PRD_FRONTEND_URL="https://your-app.com"
```

## GitHub Setup

### 1. Add Secrets (Settings → Secrets → Actions)

| Secret | Environment | Value |
|--------|-------------|-------|
| `DEPLOY_HOOK_DEV` | *(repo-level)* | Deploy hook URL for DEV |
| `DEPLOY_HOOK_SIT` | *(repo-level)* | Deploy hook URL for SIT |
| `DEPLOY_HOOK_UAT` | *(repo-level)* | Deploy hook URL for UAT |
| `DEPLOY_HOOK_PRD` | *(repo-level)* | Deploy hook URL for PRD |

### 2. Add Variables (Settings → Secrets → Variables)

| Variable | Value |
|----------|-------|
| `DEV_URL` | DEV frontend URL |
| `SIT_URL` | SIT frontend URL |
| `UAT_URL` | UAT frontend URL |
| `PRD_URL` | PRD frontend URL |

### 3. Create GitHub Environments

Create `dev`, `sit`, `uat`, `prd` in **Settings → Environments**.
Add Required Reviewers to `uat` and `prd` for manual approval gates (requires GitHub Team plan on private repos).

### 4. Branches

The installer creates `develop` from `main` and pushes both.

## The Flow

```
/binaa-dev feat: <description>
      ↓ PR → develop → CI → DEV (auto)
/binaa-sit 1.0.0
      ↓ release/1.0.0 → CI → SIT (auto)
/binaa-uat
      ↓ ✋ Approve in GitHub Actions → UAT (manual)
/binaa-prd 1.0.0
      ↓ merge → main → CI → ✋ Approve → PRD (manual)
```

| Who | What |
|-----|------|
| You | Describe task to Claude with `/binaa-dev` |
| Claude | Jira ticket → impact map → branch → opencode prompt → self-review → PR |
| opencode | All code implementation |
| CI | Lint → test → build → deploy per branch |
| You | Approve UAT and PRD gates in GitHub Actions |

## Commands (Claude Code)

| Command | Stage |
|---------|-------|
| `/binaa-dev <type>: <description>` | Start feature/fix → DEV |
| `/binaa-sit <version>` | Promote → SIT |
| `/binaa-uat` | Approve UAT gate |
| `/binaa-prd <version>` | Finish release → PRD |
| `/binaa-hotfix <n> <slug> <version>` | Emergency fix → PRD |

## Scripts

```bash
bash scripts/git-flow.sh feature-start 42 short-desc   # branch from develop
bash scripts/git-flow.sh release-start 1.0.0           # cut release, bump version
bash scripts/git-flow.sh release-finish 1.0.0          # merge to main + tag
bash scripts/git-flow.sh hotfix-start 99 fix-crash     # branch from main
bash scripts/git-flow.sh hotfix-finish 1.0.1           # merge to main + develop + tag

bash scripts/deploy-dev.sh    # re-trigger DEV deploy
bash scripts/deploy-sit.sh    # re-trigger SIT deploy
bash scripts/deploy-uat.sh    # re-trigger UAT deploy
bash scripts/deploy-prd.sh    # re-trigger PRD deploy (asks for confirmation)
```

## Docs

- [`.aidev/README.md`](.aidev/README.md) — full process and environment map
- [`.github/BRANCH_NAMING.md`](.github/BRANCH_NAMING.md) — branch naming rules
- [`.github/COMMIT_CONVENTION.md`](.github/COMMIT_CONVENTION.md) — commit format
