# /ceo — Express: plan → build, end to end

Input: **$ARGUMENTS** — a feature, bug, or production issue, described in plain words.

The walk-away path. `/ceo` runs the **whole pipeline autonomously**: plan it, organize a
sprint, build it, open a PR into `develop`. It stops only to ask **one** thing — a
gray-zone dedup decision (Step 1). For the approve-first path instead, use
`/dp-plan` → `/dp-sprint` → `/dp-build`.

**Engine flag** (optional leading token, defaults to `engines.coding` in `project.config.md`):
`--claude` (all Claude) · `--opencode` (Claude plans, opencode codes) · `--max` (race both, judge, merge).

---

## Step 0 — Run mode

```bash
eval "$(bash scripts/run-mode.sh "$ARGUMENTS")"   # $RUN_MODE + $TASK (flag stripped)
echo "🎛  Run mode: $RUN_MODE"
```
Use `$TASK` as the description from here on.

---

## Step 1 — PLAN (delegates to the /dp-plan brain)

Execute **`/dp-plan` Steps 0–6** on `$TASK`:
- classify intent + slug
- refresh project index + backlog index (token-lean scoping)
- run the **dedup ladder** → DUPLICATE / FOLD-IN / RELATED / UNRELATED
- write the spec to git + the Epic→Story into Jira

**Only stop** if the dedup verdict lands in the gray band — ask the user, then continue.
Capture the resulting Story key(s) as `<STORY_KEYS>`.

---

## Step 2 — SPRINT (auto, single-sprint)

Put the new Story (or Stories, if `$TASK` fanned out) into one sprint:
```bash
SPRINT_ID=$(bash scripts/jira-sprint.sh create "ceo-$(date +%Y%m%d-%H%M)")
bash scripts/jira-sprint.sh assign "$SPRINT_ID" <STORY_KEYS>
```
No run-order question — there is exactly one sprint.

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
