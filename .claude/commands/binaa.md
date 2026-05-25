# /binaa — Project commands (router)

Use the specific command instead:

## Work

| Command | When to use | Example |
|---------|-------------|---------|
| `/ceo <description>` | Start any feature, bug, or hotfix | `/ceo add PDF export` |
| `/ceo resume` | Continue after opencode finishes | `/ceo resume` |

## Configuration

| Command | When to use | Example |
|---------|-------------|---------|
| `/binaa-models` | View + set LLM model per agent | `/binaa-models backend github-copilot/gpt-5.3-codex` |
| `/binaa-models list` | Show all available model options | `/binaa-models list` |
| `/binaa-index` | Refresh project index (token savings) | `/binaa-index` |
| `/binaa reconfig` | Full config wizard (engine, agents, branch) | `/binaa reconfig` |

## Deploy pipeline

| Command | When to use | Example |
|---------|-------------|---------|
| `/binaa-sit <version>` | Promote develop → SIT for QA | `/binaa-sit 1.1.0` |
| `/binaa-uat` | Approve UAT gate after SIT passes | `/binaa-uat` |
| `/binaa-prd <version>` | Finish release → tag → deploy PRD | `/binaa-prd 1.1.0` |
| `/binaa-hotfix <n> <slug> <version>` | Emergency production fix | `/binaa-hotfix 99 fix-login 1.0.1` |

## Full pipeline flow

```
/binaa-dev feat: <description>
        ↓ PR merged to develop
        ↓ CI auto-deploys DEV
/binaa-sit 1.1.0
        ↓ CI auto-deploys SIT
/binaa-uat
        ↓ Manual approval in GitHub Actions
        ↓ CI auto-deploys UAT
/binaa-prd 1.1.0
        ↓ Manual approval in GitHub Actions
        ↓ CI auto-deploys PRD
```
