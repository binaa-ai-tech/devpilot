# /dp-build — Build a sprint → develop

Input: **$ARGUMENTS** — a sprint id or name (from `/dp-sprint`). Empty = the
"run first" sprint in `docs/sprints/plan.md`.

Build **every Story in the sprint** on **one branch**, run QA, and open **one PR into
`develop`** — one push per sprint. The team works in parallel per layer.

---

## Step 0 — Load config + resolve engine per layer

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

# Per-layer engine + model — resolve-engine.sh is the single source of truth
# (applies Claude-entry coupling + layer_overrides).
_resolve() { eval "$(bash scripts/resolve-engine.sh layer "$1")"; printf '%s\t%s' "$LAYER_ENGINE" "$LAYER_MODEL"; }
IFS=$'\t' read -r ENG_FE  IMPL_MODEL_FE  < <(_resolve frontend)
IFS=$'\t' read -r ENG_BE  IMPL_MODEL_BE  < <(_resolve backend)
IFS=$'\t' read -r ENG_DB  IMPL_MODEL_DB  < <(_resolve db)
IFS=$'\t' read -r ENG_INT IMPL_MODEL_INT < <(_resolve integration)
eval "$(bash scripts/resolve-engine.sh effective)"; IMPL_ENGINE="${CODING:-claude}"
```

---

## Step 1 — Resolve the sprint + its Stories

```bash
SPRINT="$ARGUMENTS"
[ -z "$SPRINT" ] && SPRINT=$(grep -m1 'Run first:' docs/sprints/plan.md | sed 's/.*(\(.*\)).*/\1/')
bash scripts/jira-sprint.sh list
```

Read `docs/sprints/plan.md` to get the Story keys in `$SPRINT`. For each Story, read its
spec `docs/requirements/<slug>.md` (scope per Story already recorded at plan time).

---

## Step 2 — One branch for the whole sprint

```bash
SPRINT_SLUG=$(echo "$SPRINT" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
bash scripts/git-flow.sh feature-start "sprint" "$SPRINT_SLUG"
BRANCH=$(git branch --show-current)
```

Move every Story in the sprint to **In Progress** and log start:
```bash
for KEY in <STORY_KEYS>; do
  bash scripts/update-jira-status.sh "$KEY" "In Progress"
  bash scripts/add-jira-comment.sh "$KEY" "▶ Sprint build started [$START_TIME] · Branch: $BRANCH · Sprint: $SPRINT"
done
```

---

## Step 3 — Team Lead: per-Story implementation plan

**Adopt Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`. For each Story,
write/refresh `docs/plans/<slug>.md` from the requirements (don't re-analyze from scratch).
Determine which layers (frontend / backend / DB / integration) each Story touches.

---

## Step 4 — Implementation (parallel per layer, all Stories)

Use `IMPL_ENGINE` from Step 0.

### Engine: `claude`
Spawn agents in parallel for the union of scoped work across the sprint's Stories:
- **Frontend** → `subagent_type: "team-frontend"`
- **Backend / DB / Integration** → `subagent_type: "team-backend"`

Each agent prompt:
> Sprint: `<SPRINT>`. Stories + specs: `<list of docs/requirements/*.md + docs/plans/*.md>`.
> Branch: `<BRANCH>`. Implement all <layer> work across these Stories per the plans.
> Read `.devpilot/skills/self-heal.md`. Run build + tests. Commit per Story with a
> conventional message referencing its key. Report what you built in 3 bullets.

### Engine: `opencode`
⚠️ Run the engine via the Bash tool directly — never emit a handoff block, never ask the
user to run anything. Write per-layer briefs at `docs/implementation/<SPRINT_SLUG>-<layer>.md`,
then execute each that exists, blocking until done:
```bash
[ -f "docs/implementation/${SPRINT_SLUG}-frontend.md" ]    && $ENG_FE  --model "$IMPL_MODEL_FE"  < "docs/implementation/${SPRINT_SLUG}-frontend.md"
[ -f "docs/implementation/${SPRINT_SLUG}-backend.md" ]     && $ENG_BE  --model "$IMPL_MODEL_BE"  < "docs/implementation/${SPRINT_SLUG}-backend.md"
[ -f "docs/implementation/${SPRINT_SLUG}-db.md" ]          && $ENG_DB  --model "$IMPL_MODEL_DB"  < "docs/implementation/${SPRINT_SLUG}-db.md"
[ -f "docs/implementation/${SPRINT_SLUG}-integration.md" ] && $ENG_INT --model "$IMPL_MODEL_INT" < "docs/implementation/${SPRINT_SLUG}-integration.md"
```

---

## Step 5 — QA (whole sprint)

Spawn `subagent_type: "team-qa"`:
> Sprint: `<SPRINT>`. Verify every acceptance criterion across all Stories. Write
> `docs/qa/<SPRINT_SLUG>.md`. Verdict per Story: PASS / BLOCKED.

If any Story is BLOCKED: fix and re-run QA before proceeding.

---

## Step 6 — One PR → develop

```bash
git add docs/ && git commit -m "docs($SPRINT_SLUG): sprint plans, qa, review"
PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$SPRINT: <n> stories" "docs/qa/${SPRINT_SLUG}.md")
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -20 | tr '\n' ' ')

if [ $? -eq 0 ]; then
  for KEY in <STORY_KEYS>; do
    bash scripts/update-jira-status.sh "$KEY" "Done"
    bash scripts/add-jira-comment.sh "$KEY" "✅ Built in sprint $SPRINT [$END_TIME] · PR: $PR_URL"
  done
else
  echo "⚠️  Auto-merge failed — merge $PR_URL manually, then mark the sprint's Stories Done."
fi
```

---

## Final Output — DONE Block

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  SPRINT BUILT — merged into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗂  Sprint:  <SPRINT>   ·   Stories: <N> (all Done)
🔀  PR:      <PR_URL> → <BASE_BRANCH>
⏱  Time:    <START_TIME> → <END_TIME>
🔖  Commits: <hash1> · <hash2> · ...

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes
📁  QA:      docs/qa/<SPRINT_SLUG>.md
──────────────────────────────────────────────────────
🚀  Promote when ready:  /dp-release sit → /dp-release uat → /dp-release prd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
