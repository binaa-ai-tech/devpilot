# /dp-hotfix — Emergency production fix

Task + version: **$ARGUMENTS**
*(e.g. `/dp-hotfix mas-99 fix-otp-expiry 1.0.1` → ticket slug, version)*

Expedited flow for production-critical bugs. Branches from `main`, ships to PRD after a
manual approval gate. Skips the backlog/sprint machinery — this is an emergency path.

## Flow
1. **Jira ticket** — `create-jira-ticket.sh`, type Bug, priority P0.
2. **Branch from `main`:**
   ```bash
   bash scripts/git-flow.sh hotfix-start <ticket> <slug>
   ```
3. **Implement** the minimal fix per the resolved engine (`engines.coding`). Minimum diff —
   no refactoring under pressure. Read `.devpilot/skills/debug-method.md` first.
4. **Self-review:** `git diff main...HEAD` — confirm scope is tight.
5. **Finish:**
   ```bash
   bash scripts/git-flow.sh hotfix-finish <version>
   ```
   Merges → `main`, tags `v<version>`, merges back → `develop`.
6. **CI on `main`** → lint → test → build → **manual PRD gate** (approve `Deploy → PRD`).
7. **Close ticket** + verify on production. Post-mortem if customer-impacting.

## Rules
- Hotfix ALWAYS branches from `main`, never `develop`.
- `develop` receives the fix automatically via `hotfix-finish`.

**Report:** Jira URL, tag, production URL to verify.
