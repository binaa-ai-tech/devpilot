# /dp-deliver — Requirement → merged into develop, end to end

Input: **$ARGUMENTS** — a feature, bug, or requirement described in plain words, or a Jira key.
Optional trailing flag: `--to sit` also cuts the SIT release after the merge.
`/dp-deliver resume` continues an interrupted run from its checkpoint.

The walk-away path. `/dp-deliver` runs the **whole team autonomously** — BA planning →
sprint → Team Lead plan → Angular + .NET implementation → QA (unit, integration, Playwright UI)
→ code review → PR → merge into `develop` (DEV deploys from there). It stops only for a
gray-zone dedup question. For the approve-first path instead, run the role commands:
`/dp-plan` → `/dp-sprint` → `/dp-build` → `/dp-pr`.

> ## 🚦 Non-negotiable invariant — the tracker comes first
> **Every `/dp-deliver` run creates the work in the tracker BEFORE a single line of code.**
> No matter the intent — bug, issue, feature, enhancement — the PLAN phase (Step 1) MUST
> land a tracker issue (Epic→Story) and you MUST capture its key. **New features additionally
> get a sprint** (Step 2). It is a hard error to branch, edit files, or spawn a build agent
> before `<STORY_KEYS>` exists — Step 1 ends with `scripts/jira-guard.sh assert-key`, which
> fails the run if the ceremony was skipped. **A P0/P1 bug is refused here** —
> `scripts/jira-guard.sh hotfix-gate` blocks it and redirects to the expedited `/dp-hotfix` lane.

> ## 🤖 Second invariant — fully autonomous, no human-in-the-loop before merge
> It **stops for exactly one thing: a gray-zone dedup question (Step 1).** It must **never**
> pause to ask you to *test, verify, review, or approve before merging*. **QA is the `team-qa`
> agent plus the automated suites**, review is the Team Lead gate, and the merge gate is
> `.devpilot/skills/auto-merge.md`. With `merge_policy: auto` the run merges itself. The only
> legitimate stops short of merge: a red gate the bounded fix loop couldn't clear (escalate
> with the self-heal template) or `merge_policy: pr-only` (a human merges). Production is
> never touched — `/dp-release prd` keeps its human approval.

Models are Claude only, balanced per task by `scripts/resolve-model.sh` (Opus for
architectural work, Sonnet for normal work, Haiku for light work).

---

## Step 0 — Parse input + tracker preflight

```bash
TASK="$ARGUMENTS"; PROMOTE_TO=""
case "$TASK" in *"--to sit"*) PROMOTE_TO="sit"; TASK="${TASK/--to sit/}" ;; esac
# Hard gate #1: the tracker must be able to accept the issue.
bash scripts/jira-guard.sh check || exit 1
```
If `$TASK` is `resume`: read the latest checkpoint (`bash scripts/checkpoint.sh latest`, then
`bash scripts/checkpoint.sh show <KEY>`) and continue from its `next_phase` — do not redo
completed phases.

---

## Step 1 — PLAN (delegates to the /dp-plan brain)

Execute **`/dp-plan` Steps 0–6** on `$TASK`:
- classify intent + slug (carry `$INTENT` forward — it decides Step 2)
- refresh project index + backlog index (token-lean scoping)
- run the **dedup ladder** → DUPLICATE / FOLD-IN / RELATED / UNRELATED
- write the spec to git + the Epic→Story into Jira

**Only stop** if the dedup verdict lands in the gray band — ask the user, then continue.
Capture the resulting Story key(s) as `<STORY_KEYS>` (every verdict resolves to at least
one key: a new Story for RELATED/UNRELATED, or the existing/target key for FOLD-IN/DUPLICATE).

**Hard gate #2 — do not advance without a tracker issue:**
```bash
bash scripts/jira-guard.sh assert-key <STORY_KEYS> || exit 1
```
If this fails, the ceremony was skipped — go back and create the issue. **Never** continue
to Step 2/3 (sprint or build) without it.

---

## Step 2 — SPRINT (routed by intent)

The Jira issue from Step 1 is mandatory for every intent; **how it reaches a sprint depends
on the intent:**

- **`feature` / `enhancement` / `task` / `requirement`** → a new feature ships **through its
  own sprint**. Create one and assign the Story:
  ```bash
  SPRINT_ID=$(bash scripts/jira-sprint.sh create "deliver-${INTENT}-$(date +%Y%m%d-%H%M)")
  bash scripts/jira-sprint.sh assign "$SPRINT_ID" <STORY_KEYS>
  ```
- **`bug` / `issue`** → a defect **joins the active sprint**, it does not spawn a new one. If
  there's no active sprint, fall back to a single bugfix sprint so Step 3 has one to resolve:
  ```bash
  SPRINT_ID=$(bash scripts/jira-sprint.sh active)
  [ -z "$SPRINT_ID" ] && SPRINT_ID=$(bash scripts/jira-sprint.sh create "deliver-bugfix-$(date +%Y%m%d-%H%M)")
  bash scripts/jira-sprint.sh assign "$SPRINT_ID" <STORY_KEYS>
  ```
  (P0/P1 production-critical bugs never reach this step — `hotfix-gate` in Step 1 already
  blocked them and redirected to `/dp-hotfix`. See `.devpilot/process.md`.)

No run-order question — there is exactly one sprint in play.

---

## Step 3 — BUILD → QA → REVIEW → MERGE (delegates to /dp-build)

Execute **`/dp-build` Steps 0–6** for `$SPRINT_ID`: one branch → implement (parallel per
layer) → QA → review gate → **one PR into `develop`**, driven to merged per `auto-merge.md`.
If CI goes red after the PR opens, run the `/dp-pr` loop on it — don't stop at "PR opened".

## Step 4 — Promote (only with `--to sit`)

After a **confirmed** merge, when `PROMOTE_TO = sit`: take the next SemVer (MINOR for features,
PATCH for bugs, from `git tag --sort=-version:refname | head -1`) and run
**`/dp-release sit <version>`**. UAT and PRD stay separate, human-gated steps.

---

## Final Output

Emit the `/dp-build` DONE block, prefixed:
```
🤖  /dp-deliver — planned → built → tested → reviewed → merged
```
Then the promote ladder: `/dp-release sit → uat → prd` (or what's left of it after `--to sit`).
