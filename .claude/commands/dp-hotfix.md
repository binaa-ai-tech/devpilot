# /dp-hotfix — Emergency production fix

Task + version: **$ARGUMENTS**
*(e.g. `/dp-hotfix MSK-99 fix-otp-expiry 1.0.1` — key, slug, version. No key → one is created;
no version → the next PATCH above production: `bash scripts/version.sh next patch --ref origin/main`)*

Expedited flow for production-critical bugs. Branches from `main`, ships to PRD after a
manual approval gate. Skips the backlog/sprint machinery — this is an emergency path.

## Flow
1. **Tracker item** — reuse the key, or create it:
   `KEY=$(bash scripts/tracker.sh new Bug "<summary>" "<impact + repro>" "" "hotfix,sev-p0")`,
   then `bash scripts/tracker.sh status "$KEY" "In Progress"`.
2. **Branch from `main`:**
   ```bash
   bash scripts/git-flow.sh hotfix-start "$KEY" <slug>
   ```
3. **Implement** the minimal fix with the `team-dotnet` / `team-frontend` agent for the affected layer. Minimum diff —
   no refactoring under pressure. Follow the debugging method in `.devpilot/skills/self-heal.md` (Part 0) first.
4. **Self-review:** `git diff main...HEAD` — confirm scope is tight.
5. **Finish:**
   ```bash
   bash scripts/git-flow.sh hotfix-finish <version>
   ```
   Merges → `main`, tags `v<version>`, merges back → `develop`.
6. **CI on `main`** → lint → test → build → **manual PRD gate** (approve `Deploy → PRD`).
7. **Verify on production, then close:** `bash scripts/tracker.sh comment "$KEY" "🚑 Hotfix v<version>
   deployed · verified on PRD"` and `bash scripts/tracker.sh close "$KEY"`.
8. **Postmortem** — apply the incidents section of `.devpilot/skills/release-ops.md`. Write a blameless
   postmortem to `docs/postmortems/<ticket>-<slug>.md` (timeline, root cause, action items),
   and turn each action item into a backlog Story via `/dp-plan`. Skip only for trivial
   internal-only blips.

## Rules
- Hotfix ALWAYS branches from `main`, never `develop`.
- `develop` receives the fix automatically via `hotfix-finish`.

**Report:** item link (`bash scripts/tracker.sh url "$KEY"`), tag, production URL to verify, postmortem path.
