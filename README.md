# binaa-ai Dev Process

AI-assisted development flow. From idea to SIT in one conversation.

## Install into any project

```bash
curl -s https://raw.githubusercontent.com/binaa-ai/dev-process/main/install.sh | bash
```

## Configure

Edit `.aidev/config.sh`:

```bash
JIRA_BASE_URL="https://YOUR-ORG.atlassian.net"
JIRA_EMAIL="your-email@example.com"
JIRA_API_TOKEN="your-token"
JIRA_PROJECT_KEY="XXX"

GITHUB_ORG="binaa-ai"
GITHUB_REPO="your-repo"

SIT_FRONTEND_URL="https://your-app.vercel.app"
SIT_API_URL="https://your-api.onrender.com"

OPENCODE_MODEL="github-copilot/gpt-5.4-codex"
```

> `.aidev/config.sh` is gitignored — never committed.

## GitHub Secrets (under SIT environment)

| Secret | Value |
|---|---|
| `API_DEPLOY_HOOK_URL` | Render deploy hook URL |
| `WEB_DEPLOY_HOOK_URL` | Vercel deploy hook URL |

## The Flow

| Who | What |
|---|---|
| You | Describe task to Claude |
| Claude | Creates Jira ticket → impact map → branch → implements → reviews → opens PR |
| GitHub Actions | Builds + deploys to SIT automatically |
| You | Receive email → test on SIT |

## Scripts

```bash
./scripts/new-feature.sh MSK-101 short-desc   # create branch
./scripts/deploy-sit.sh                        # deploy main → SIT
./scripts/create-jira-ticket.sh "Title" "Desc" "Story"
```

## Docs

See `docs/dev-flow.md` for the full process guide.
