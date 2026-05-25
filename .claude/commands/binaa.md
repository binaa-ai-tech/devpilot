# /binaa — Project deployment pipeline (router)

Use the environment-specific command instead:

| Command | When to use | Example |
|---------|-------------|----------|
| `/binaa-dev <type>: <description>` | Start a new feature or fix → lands on DEV | `/binaa-dev feat: add user search feature` |
| `/binaa-sit <version>` | Promote develop → SIT for QA testing | `/binaa-sit 1.1.0` |
| `/binaa-uat` | Approve UAT gate after SIT passes | `/binaa-uat` |
| `/binaa-prd <version>` | Finish release → tag → deploy PRD | `/binaa-prd 1.1.0` |
| `/binaa-hotfix <n> <slug> <version>` | Emergency production fix | `/binaa-hotfix 99 fix-critical-bug 1.0.1` |

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
