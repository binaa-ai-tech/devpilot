# /binaa-hotfix — Emergency production fix

Runs an expedited flow for production-critical bugs. Branches from `main`, implements the fix, and ships directly to PRD after a manual approval gate.

Task + version: **$ARGUMENTS**  
*(e.g. `/binaa-hotfix mas-99 fix-otp-expiry 1.0.1`  →  ticket, slug, patch version)*

---

Read `.aidev/prompts/0-start-work.md` (hotfix section) and execute the hotfix flow for the task above.

## What this command does

1. **Jira ticket** — create with type=Bug, priority=P0
2. **Impact map** — brief version, focus on root cause + rollback plan
3. **Hotfix branch** (from `main`):
   ```bash
   bash scripts/git-flow.sh hotfix-start <ticket> <slug>
   ```
4. **Implement** — build minimal opencode prompt, tell user to run opencode
5. **Self-review** — `git diff main...HEAD` — minimum diff, no scope creep
6. **Finish hotfix**:
   ```bash
   bash scripts/git-flow.sh hotfix-finish <version>
   ```
   Merges hotfix → `main`, tags `v<version>`, merges back → `develop`

7. **CI triggers on `main`** — lint → test → build → **(manual PRD gate)**
   - Open: https://github.com/binaa-ai-tech/maskan/actions
   - Approve the `Deploy → PRD` job

8. **Close ticket** + verify fix on production

## Rules
- Never implement code directly — opencode does step 4
- Minimum diff only — no refactoring under pressure
- Hotfix ALWAYS branches from `main`, not `develop`
- `develop` gets the fix automatically via `hotfix-finish`

## When done, report:
- Jira ticket URL
- Git tag created
- Production URL to verify
- Post-mortem reminder if customer-impacting
