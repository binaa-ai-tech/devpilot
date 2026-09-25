# /dp-build — Build a sprint → versioned PR → merged into develop → items closed

Input: **$ARGUMENTS** — a sprint id or name (from `/dp-sprint`). Empty = the "run first" sprint in
`docs/sprints/plan.md`. (`/dp-deliver` calls this with its own sprint and Story keys.)

Build **every Story in the sprint** on **one branch**, run QA, bump the version, open **one PR
into `develop`**, merge it when every gate is green, then close the items and the sprint.

---

## Step 0 — Load config + pick the model tier

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | awk '{print $2}' | tr -d '"')
BUMP=$(awk '/^versioning:/{f=1;next} f&&/^[^[:space:]#]/{f=0} f&&/bump:/{print $2;exit}' project.config.md); BUMP="${BUMP:-auto}"
eval "$(bash scripts/resolve-model.sh suggest "<sprint name + story summaries>")"   # COMPLEXITY, TIER, MODEL
```
Agents run on their role model (`.claude/agents/*.md`); when `TIER=power`, spawn the
implementation agents with `model: "opus"`.

---

## Step 1 — Resolve the sprint + its Stories

```bash
SPRINT="$ARGUMENTS"
[ -z "$SPRINT" ] && SPRINT=$(grep -m1 'Run first:' docs/sprints/plan.md | sed 's/.*(\(.*\)).*/\1/')
bash scripts/tracker.sh sprint list
```
Story keys come from `docs/sprints/plan.md` (or from `/dp-deliver`). For each, read
`docs/requirements/<slug>.md`. **Fresh checkout / other session:** `bash scripts/tracker.sh show
<KEY>` — the description is a self-contained brief (full ACs, scope, DoD); the tracker is enough.

Note each Story's intent (feature / enhancement / bug …) → `INTENTS`.

---

## Step 2 — One branch for the whole sprint

```bash
SPRINT_SLUG=$(echo "$SPRINT" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
# One Story → feature/<key>-<slug> (e.g. feature/ado-345-csv-export); several → feature/<prefix>-sprint-<slug>
bash scripts/git-flow.sh feature-start "<KEY or 'sprint'>" "<slug or $SPRINT_SLUG>"
BRANCH=$(git branch --show-current)
bash scripts/tracker.sh sprint start "$SPRINT" 2>/dev/null || true
for KEY in <STORY_KEYS>; do
  bash scripts/tracker.sh status "$KEY" "In Progress"
  bash scripts/tracker.sh comment "$KEY" "▶ Build started [$START_TIME] · Branch: $BRANCH · Sprint: $SPRINT"
  bash scripts/tracker.sh breakdown "$KEY" "<layers of this Story>,qa" "<summary>" >/dev/null   # no-op if planned
done
```
Layer tasks follow the work: `[BE]`/`[DB]` → In Progress when `team-dotnet` starts, `[FE]` when
`team-frontend` starts, `[QA]` when `team-qa` starts; each → **Done** when that agent reports green
(`bash scripts/tracker.sh status <TASK> "In Progress" | "Done"`). Keys: `bash scripts/tracker.sh show <KEY>`.

---

## Step 3 — Team Lead: per-Story implementation plan

**Adopt the Team Lead persona** (`.devpilot/prompts/team/lead-plan.md`). For each Story write or
refresh `docs/plans/<slug>.md` from the requirements. **Reuse the saved scope**
(`docs/tasks/<slug>-scope.md`); only if missing: `bash scripts/scope.sh --save <slug> "<summary>"`.
Decide the layers each Story touches (frontend / backend / DB).

---

## Step 4 — Implementation (parallel per layer, all Stories)

- **Frontend (Angular)** → `subagent_type: "team-frontend"`
- **Backend / DB (.NET + SQL Server)** → `subagent_type: "team-dotnet"`

When both layers change an API, the backend agent commits the regenerated OpenAPI spec first;
the frontend agent regenerates the Angular client from it (`api-contract`).

Each agent prompt:
> Sprint `<SPRINT>` · Stories + specs: `<docs/requirements/*.md + docs/plans/*.md>` · Branch
> `<BRANCH>`. Implement all <layer> work per the plans. Read `.claude/skills/self-heal/SKILL.md`.
> Build + test with `bash scripts/run-tests.sh <angular|dotnet>` (summary only). Commit per
> Story, conventional message ending with the tracker ref (`bash scripts/tracker.sh ref <KEY>` →
> `MSK-12` · `AB#345` · `#7`). Report what you built in 3 bullets.

---

## Step 5 — QA (whole sprint)

QA is automated and is the only test gate — never pause for the user to test or sign off.

Spawn `subagent_type: "team-qa"`:
> Sprint `<SPRINT>`. Verify every AC of every Story: case matrix per AC
> (`test-case-design`), layers per `test-strategy`, a Playwright journey for every
> user-facing AC (`ui-e2e-playwright`; `performance` only for a perf AC). Run everything
> via `bash scripts/run-tests.sh all`, gate on `definition-of-done`, write
> `docs/qa/<SPRINT_SLUG>.md`. Verdict per Story: PASS / BLOCKED.

BLOCKED → `bash scripts/notify.sh blocked "QA BLOCKED in $SPRINT: <keys + reason>"`, fix, re-run QA.

---

## Step 6 — Review gate + version bump + one PR → develop

**Review (Team Lead):** `.claude/skills/review-checklist/SKILL.md`, `security-scan` over auth/input
changes, `definition-of-done` — never open around a 🔴 BLOCKER. Then:
```bash
STRICT=1 bash scripts/test-guard.sh
```

**Version** (skip when `BUMP=off`) — bumped **from develop's current version**, so two PRs in
flight never skip or reuse a number:
```bash
git fetch origin "$BASE_BRANCH" -q
LEVEL=$(bash scripts/version.sh level $INTENTS)           # any feature → minor, bugs only → patch
VERSION=$(bash scripts/version.sh bump "$LEVEL" --ref "origin/$BASE_BRANCH")
bash scripts/version.sh files | xargs git add
# One changelog entry per Story — its own file, so parallel PRs never conflict on CHANGELOG.md
for KEY in <STORY_KEYS>; do
  bash scripts/changelog.sh add "$KEY" "<feat|fix per the Story's intent>" "<user-facing one-liner>" "$(bash scripts/tracker.sh url "$KEY")"
done
git add docs/changes
git commit -m "chore(release): bump version to $VERSION"
```

**PR body** — `docs/tasks/<SPRINT_SLUG>-pr.md`:
```markdown
## <sprint or story summary>
**Version:** v<VERSION> (<LEVEL>) · **Sprint:** <SPRINT>
### Items
- [<KEY>](<tracker.sh url KEY>) — <title>   (one line per Story; add `<tracker.sh ref KEY>`)
### QA
<verdict table from docs/qa/<SPRINT_SLUG>.md> · Review: docs/reviews/<slug>.md
<!-- devpilot: keys="<STORY_KEYS>" sprint="<SPRINT>" version="<VERSION>" -->
```
The last line lets `/dp-pr` finish the job (close items + sprint) on a later run.

```bash
# Local tracker only: close the items INSIDE the PR (they are files in git; develop only
# changes via PRs) — they become Done exactly when it merges. No-op for Jira/Azure/GitHub.
bash scripts/close-delivery.sh --prepare --version "$VERSION" --sprint "$SPRINT" <STORY_KEYS>
git add docs/ && git commit -m "docs($SPRINT_SLUG): plans, qa, review" || true
TITLE="[v$VERSION] <summary> ($(for K in <STORY_KEYS>; do bash scripts/tracker.sh ref "$K"; done | paste -sd' ' -))"
PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$TITLE" "docs/tasks/${SPRINT_SLUG}-pr.md" --items "<STORY_KEYS>"); PR_RC=$?
echo "open-pr rc=$PR_RC (0 merged · 3 open/waiting · 1 error)"
```

> **🔌 Transport.** `open-pr.sh` detects the host (`scripts/git-host.sh`):
> **Azure Repos** → `azdo.sh pr-create` + auto-complete (squash, delete branch; completes the
> moment branch policies pass). **GitHub** → `gh` (merge, or `--auto` while checks run). **GitHub
> without `gh`** (Claude Code on the web) → rc 3 with a compare URL: create the PR with
> `mcp__github__create_pull_request`, then merge with `mcp__github__merge_pull_request`
> (`merge_method: "squash"`) once the ladder is green. Never stop at the compare URL.

Resolve by exit code:
- **`PR_RC = 0`** — merged. → Step 7.
- **`PR_RC = 3`** — open, not merged: `merge_policy: pr-only` → report and stop (a human merges).
  Otherwise drive it with the **`/dp-pr` loop** (review threads, CI fix cycles ≤ 3, merge per
  `auto-merge`), then → Step 7 once the merge is **confirmed**.
- **`PR_RC = 1`** — hard error; report it. Items stay In Progress.

---

## Step 7 — Close (only after a CONFIRMED merge)

```bash
bash scripts/close-delivery.sh --pr "$PR_URL" --version "$VERSION" --sprint "$SPRINT" <STORY_KEYS>
bash scripts/generate-backlog-index.sh
bash scripts/notify.sh done "v$VERSION merged into $BASE_BRANCH — <N> item(s) · $PR_URL"
```
`close-delivery.sh`: any open layer task + comment + **Done** on every Story → parent **Epic Done** when all its
children are → **sprint closed** when nothing in it is open (otherwise reported, left open) →
checkout `develop`, pull, delete the merged branch locally. Unmerged (pr-only / red gate)? Keep
the items In Progress: `bash scripts/notify.sh blocked "PR open, not merged — $PR_URL"`.

---

## Final Output — DONE Block

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  v<VERSION> MERGED into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗂  Sprint:   <SPRINT> <closed | open (n left)>   ·   Stories: <N> Done
🔀  PR:       <PR_URL>  (squash-merged, branch deleted)
⏱  Time:     <START_TIME> → <END_TIME>
📁  QA:       docs/qa/<SPRINT_SLUG>.md
📍  Now on:   <BASE_BRANCH> (pulled)
──────────────────────────────────────────────────────
🚀  Promote when ready:  /dp-release sit → uat → prd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
