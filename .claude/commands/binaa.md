# /binaa — Maskan development commands (router)

Use the environment-specific command instead:

| Command | When to use | Example |
|---------|-------------|---------|
| `/binaa-dev <type>: <description>` | Start a new feature or fix → lands on DEV | `/binaa-dev feat: add map filter for Cairo zones` |
| `/binaa-sit <version>` | Promote develop → SIT for QA testing | `/binaa-sit 1.1.0` |
| `/binaa-uat` | Approve UAT gate after SIT passes | `/binaa-uat` |
| `/binaa-prd <version>` | Finish release → tag → deploy PRD | `/binaa-prd 1.1.0` |
| `/binaa-hotfix <n> <slug> <version>` | Emergency production fix | `/binaa-hotfix 99 fix-otp-expiry 1.0.1` |

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

---

## AI Dev Team Commands

| Command | When to use | Example |
|---------|-------------|---------|
| `/team-task <description>` | Start any task end-to-end with the full AI team | `/team-task feat: add user profile avatar upload` |
| `/team-ba <description>` | Business Analyst only — just need requirements | `/team-ba add a notifications panel` |
| `/team-lead <context>` | Team Lead planning or review only | `/team-lead docs/requirements/notifications.md` |
| `/team-frontend <context>` | Frontend Developer only | `/team-frontend docs/plans/notifications.md` |
| `/team-dotnet <context>` | .NET Developer only | `/team-dotnet docs/plans/notifications.md` |
| `/team-qa <context>` | QA Engineer only | `/team-qa docs/requirements/notifications.md` |
