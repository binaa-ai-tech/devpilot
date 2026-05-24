# /binaa-dev — Start a task → develop → DEV

Runs the full `.aidev` 7-step process and lands the work on the DEV environment.

Task: **$ARGUMENTS**

---

Read `.aidev/prompts/0-start-work.md` and execute **Steps 1–7a** for the task above.

## What this command does

1. **Jira ticket** — create via `./scripts/create-jira-ticket.sh`
2. **Impact map** — write `.aidev/impact-maps/<KEY>.md`
3. **Branch** — `bash scripts/git-flow.sh feature-start <n> <slug>` (from `develop`)
4. **Implement** — build opencode prompt from `prompts/4-implement-*.md`, tell user to run opencode
5. **Self-review** — `git diff develop...HEAD` against `rules.md`
6. **PR → develop** — `gh pr create --base develop`, `gh pr merge --auto --squash --delete-branch`
7. **Wait for CI + DEV deploy** — watch Actions, confirm DEV is live

## Rules
- Never implement code directly — opencode does step 4
- Never commit to `main` or `develop` directly — always via PR
- Branch always cut from latest `develop`
- PR always targets `develop`

## When done, report:
- Jira ticket URL
- PR URL  
- What was implemented (3 bullets)
- DEV environment URL to test
- Next command to run: `/binaa-sit <version>`
