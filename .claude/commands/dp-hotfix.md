# /dp-hotfix — Emergency production fix

Task + version: **$ARGUMENTS**
*(e.g. `/dp-hotfix MSK-99 fix-otp-expiry 1.0.1` — key, slug, version. No key → one is created;
no version → the next PATCH above production: `bash scripts/version.sh next patch --ref origin/main`)*

Expedited flow for production-critical bugs. Branches from `main`, ships SIT → PRD through the
CD pipeline behind the production approval. Skips the backlog/sprint machinery — this is an emergency path.

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
5. **Ship through the pipeline** — push the branch; `devpilot-cd` builds it once → **SIT** (smoke)
   → waits for the **PRD approval** (hotfixes skip UAT). Tell the user to approve PRD once SIT is
   green (`/dp-release` → *Reading the pipeline*). Red → fix on the branch, never bypass.
   ```bash
   VERSION=${VERSION:-$(bash scripts/version.sh next patch --ref origin/main)}
   bash scripts/version.sh bump "$VERSION" >/dev/null && bash scripts/version.sh files | xargs git add
   git commit -m "chore(release): hotfix v$VERSION" && git push -u origin "$(git branch --show-current)"
   ```
6. **Finish after PRD is green** — so `main` and the tag match what is live:
   ```bash
   bash scripts/git-flow.sh hotfix-finish "$VERSION"     # PR → main, tag, PR → develop (re-run while PRs are pending)
   ```
7. **Verify on production, then close:** `bash scripts/tracker.sh comment "$KEY" "🚑 Hotfix v<version>
   deployed · verified on PRD"` and `bash scripts/tracker.sh close "$KEY"`.
8. **Postmortem** — apply the incidents section of `.devpilot/skills/release-ops.md`. Write a blameless
   postmortem to `docs/postmortems/<ticket>-<slug>.md` (timeline, root cause, action items),
   and turn each action item into a backlog Story via `/dp-plan`. Skip only for trivial
   internal-only blips.

## Rules
- Hotfix ALWAYS branches from `main`, never `develop`.
- `develop` receives the fix through the back-merge PR `hotfix-finish` opens — never a direct push.

**Report:** item link (`bash scripts/tracker.sh url "$KEY"`), tag, production URL to verify, postmortem path.
