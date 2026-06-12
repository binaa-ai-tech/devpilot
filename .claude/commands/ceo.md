# /ceo — Express: plan → build, end to end

Input: **$ARGUMENTS** — a feature, bug, or production issue, described in plain words.

The walk-away path. `/ceo` runs the **whole pipeline autonomously**: plan it, organize a
sprint, build it, open a PR into `develop`. It stops only to ask **one** thing — a
gray-zone dedup decision (Step 1). For the approve-first path instead, use
`/dp-plan` → `/dp-sprint` → `/dp-build`.

> ## 🚦 Non-negotiable invariant — the tracker comes first
> **Every `/ceo` run creates the work in the tracker BEFORE a single line of code.**
> No matter the intent — bug, issue, hotfix, feature, enhancement — the PLAN phase
> (Step 1) MUST land a Jira issue (Epic→Story) and you MUST capture its key. **New
> features additionally get a sprint** (Step 2). It is a hard error to branch, edit
> files, or spawn a build agent before `<STORY_KEYS>` exists — Step 1 ends with
> `scripts/jira-guard.sh assert-key`, which fails the run if the ceremony was skipped.
> Being "efficient" by jumping straight to the code fix is the one thing `/ceo` must
> never do.

**Engine flag** (optional leading token, defaults to `engines.coding` in `project.config.md`):
`--claude` (Claude models) · `--opencode` (Claude plans; opencode/GitHub Copilot codes).
Within the chosen family, the model is picked **per task** — power vs token-saving — by
`resolve-engine.sh`. opencode falls back to its own default model when Copilot is unavailable.

---

## Step 0 — Run mode + tracker preflight

```bash
eval "$(bash scripts/run-mode.sh "$ARGUMENTS")"   # $RUN_MODE + $TASK (flag stripped)
echo "🎛  Run mode: $RUN_MODE"

# Hard gate #1: the tracker must be able to accept the issue. If Jira is the
# selected tracker but unconfigured, STOP and surface the fix — do not silently
# fall through to a code-only run.
bash scripts/jira-guard.sh check || exit 1
```
Use `$TASK` as the description from here on.

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
  SPRINT_ID=$(bash scripts/jira-sprint.sh create "ceo-${INTENT}-$(date +%Y%m%d-%H%M)")
  bash scripts/jira-sprint.sh assign "$SPRINT_ID" <STORY_KEYS>
  ```
- **`bug` / `issue`** → a defect **joins the active sprint**, it does not spawn a new one. If
  there's no active sprint, fall back to a single bugfix sprint so Step 3 has one to resolve:
  ```bash
  SPRINT_ID=$(bash scripts/jira-sprint.sh active)
  [ -z "$SPRINT_ID" ] && SPRINT_ID=$(bash scripts/jira-sprint.sh create "ceo-bugfix-$(date +%Y%m%d-%H%M)")
  bash scripts/jira-sprint.sh assign "$SPRINT_ID" <STORY_KEYS>
  ```
  (P0/P1 production-critical bugs belong on `/dp-hotfix`, not `/ceo` — see `.devpilot/process.md`.)

No run-order question — there is exactly one sprint in play.

---

## Step 3 — BUILD (delegates to the /dp-build engine)

Execute **`/dp-build` Steps 0–6** for `$SPRINT_ID` with run mode `$RUN_MODE`:
one branch → implement (parallel per layer) → QA → **one PR into `develop`**, Stories → Done.

---

## Final Output

Emit the `/dp-build` DONE block, prefixed:
```
🤖  /ceo express run — plan → sprint → build complete
```
Then the promote ladder: `/dp-release sit → uat → prd`.
