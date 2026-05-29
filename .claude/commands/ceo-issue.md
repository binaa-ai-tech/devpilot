# /ceo-issue — CEO Issue Loop (Track 2)

Issue: **$ARGUMENTS**

**Track 2 flow:** Bypasses BA entirely. Team Lead triages the issue, creates targeted Jira
sub-tasks per layer, spawns targeted dev agents, resolves, updates Jira. Used for bugs,
incidents, or issues where requirements are already clear from the problem description.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 \
  | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

# Resolve engine + model PER LAYER via resolve-engine.sh — the single source of
# truth. It applies the Claude-entry coupling (runner=claude → all Claude) and any
# layer_overrides. ENG_<layer> = engine for that layer; IMPL_MODEL_<layer> = model.
_resolve() { eval "$(bash scripts/resolve-engine.sh layer "$1")"; printf '%s\t%s' "$LAYER_ENGINE" "$LAYER_MODEL"; }
IFS=$'\t' read -r ENG_FE  IMPL_MODEL_FE  < <(_resolve frontend)
IFS=$'\t' read -r ENG_BE  IMPL_MODEL_BE  < <(_resolve backend)
IFS=$'\t' read -r ENG_DB  IMPL_MODEL_DB  < <(_resolve db)
IFS=$'\t' read -r ENG_INT IMPL_MODEL_INT < <(_resolve integration)

# Layer-agnostic default engine (coupled CODING) for logging / references.
eval "$(bash scripts/resolve-engine.sh effective)"
IMPL_ENGINE="$CODING"; [ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"
```

---

## Step 1 — Team Lead: Triage

**Adopt Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md` and `.devpilot/skills/debug-method.md` (reproduce → localize → root cause before changing code).

1. Ensure project index is fresh:
   ```bash
   if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
     echo "Index fresh — skipping"
   else
     bash scripts/generate-project-index.sh
   fi
   ```
   Read `docs/project-index.md` — identify affected files/layers.

2. Triage the issue: `$ARGUMENTS`
   - **Root cause hypothesis**: what is broken and why (based on reading affected files)
   - **Layers affected**: frontend / backend / DB / integration (check each)
   - **Severity**: P0 (users blocked) / P1 (major degradation) / P2 (minor issue)
   - **Sub-task breakdown**: one sub-task per affected layer

3. Derive slug from `$ARGUMENTS`:
   - Lowercase, hyphens only, max 5 words
   - Example: "login page 500 on mobile" → `fix-login-500-mobile`

---

## Step 2 — Create Jira Epic + Sub-Tasks

Create one parent Epic and one child Task per affected layer.

```bash
# Derive a slug from the issue, then pre-flight scan to enrich the thin issue
# with local signal (recent commits, working-tree diff, in-scope files).
SLUG=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40)
PREFLIGHT=$(bash scripts/preflight-scan.sh "$ARGUMENTS" "$SLUG")

# Parent Epic
EPIC_KEY=$(bash scripts/create-jira-epic.sh \
  "[Issue] <one-line issue summary>" \
  "Issue: $ARGUMENTS | Root cause: <hypothesis> | Severity: <P0/P1/P2>")
bash scripts/update-jira-status.sh "$EPIC_KEY" "In Progress"

# Sub-tasks — create ONLY for layers that have work
# Frontend sub-task (if frontend affected)
KEY_FE=$(bash scripts/create-jira-ticket.sh \
  "[FE] <frontend fix summary>" \
  "Fix frontend issue: $ARGUMENTS" "Task")
bash scripts/update-jira-status.sh "$KEY_FE" "In Progress"

# Backend sub-task (if backend affected)
KEY_BE=$(bash scripts/create-jira-ticket.sh \
  "[BE] <backend fix summary>" \
  "Fix backend issue: $ARGUMENTS" "Task")
bash scripts/update-jira-status.sh "$KEY_BE" "In Progress"

# DB sub-task (if DB affected)
KEY_DB=$(bash scripts/create-jira-ticket.sh \
  "[DB] <db fix summary>" \
  "Fix DB issue: $ARGUMENTS" "Task")
bash scripts/update-jira-status.sh "$KEY_DB" "In Progress"
```

Log triage to Epic:
```bash
bash scripts/add-jira-comment.sh "$EPIC_KEY" "🔍 Triage complete [$START_TIME]
Root cause: <hypothesis>
Severity: <P0/P1/P2>
Layers: <frontend / backend / DB>
Sub-tasks: ${KEY_FE:-none} ${KEY_BE:-none} ${KEY_DB:-none}
Branch: feature/<slug>"
```

---

## Step 3 — Create Branch

```bash
TICKET_NUM=$(echo "$EPIC_KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Write checkpoint:
```bash
bash scripts/checkpoint.sh write \
  --key "$EPIC_KEY" \
  --slug "$SLUG" \
  --branch "$BRANCH" \
  --base-branch "$BASE_BRANCH" \
  --command "/ceo-issue" \
  --task "$ARGUMENTS" \
  --runner "claude" \
  --coding-engine "$IMPL_ENGINE" \
  --phase-completed "triage" \
  --next-phase "implementation" \
  --agents-completed "lead" \
  --agents-remaining "<fe,be,db as applicable>" \
  --pause-reason "none"
```

---

## Step 4 — Targeted Implementation (Layer-Locked)

Spawn only the agent(s) whose sub-task was created. Each agent is **locked to its layer**
— it must not touch files outside its scope.

### Engine: `claude`

**Frontend agent** (spawn only if KEY_FE was created):

Spawn `subagent_type: "team-frontend"`:
> Issue fix: `$ARGUMENTS`. Jira: `<KEY_FE>`. Branch: `<BRANCH>`.
> Root cause: `<root cause hypothesis>`.
> **SCOPE LOCK: You may ONLY modify files in these paths: `<frontend directories from project index>`. Do not touch any backend, DB, or shared files.**
> Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`.
> Make the minimal change. Run lint + build. Commit: `fix(<slug>): <description>`.
> Report: commit hash + files changed.

**Backend agent** (spawn only if KEY_BE was created):

Spawn `subagent_type: "team-backend"`:
> Issue fix: `$ARGUMENTS`. Jira: `<KEY_BE>`. Branch: `<BRANCH>`.
> Root cause: `<root cause hypothesis>`.
> **SCOPE LOCK: You may ONLY modify files in these paths: `<backend directories from project index>`. Do not touch any frontend, DB migration, or shared-model files unless they are part of a direct backend contract change.**
> Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`.
> Run `dotnet build && dotnet test`. Commit: `fix(<slug>): <description>`.
> Report: commit hash + files changed.

**DB agent** (spawn only if KEY_DB was created):

Spawn `subagent_type: "team-backend"`:
> DB issue fix: `$ARGUMENTS`. Jira: `<KEY_DB>`. Branch: `<BRANCH>`.
> **SCOPE LOCK: Migrations and stored procedures ONLY. Do not touch application code.**
> Read `.devpilot/rules.md → SQL Server` section.
> Make the migration idempotent. Commit: `fix(<slug>): <description>`.
> Report: commit hash + migration files.

Run agents in parallel when multiple layers are affected.

### Engine: `opencode` or `antigravity`

Write one brief per layer at `docs/implementation/<SLUG>-<layer>.md`.
Include the SCOPE LOCK constraint in every brief.
⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**
Write briefs then immediately run each via Bash tool:
```bash
[ -f "docs/implementation/${SLUG}-frontend.md" ]    && $ENG_FE  --model "$IMPL_MODEL_FE"  < "docs/implementation/${SLUG}-frontend.md"
[ -f "docs/implementation/${SLUG}-backend.md" ]     && $ENG_BE  --model "$IMPL_MODEL_BE"  < "docs/implementation/${SLUG}-backend.md"
[ -f "docs/implementation/${SLUG}-db.md" ]          && $ENG_DB  --model "$IMPL_MODEL_DB"  < "docs/implementation/${SLUG}-db.md"
[ -f "docs/implementation/${SLUG}-integration.md" ] && $ENG_INT --model "$IMPL_MODEL_INT" < "docs/implementation/${SLUG}-integration.md"
```
Proceed to QA when all commands exit 0.

---

## Step 5 — Verify + Update Sub-Task Jira

After each agent completes:

```bash
IMPL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

# Update each sub-task
[ -n "${KEY_FE:-}" ] && bash scripts/add-jira-comment.sh "$KEY_FE" "⚙️ FE fix committed [$IMPL_TIME] — $COMMITS"
[ -n "${KEY_BE:-}" ] && bash scripts/add-jira-comment.sh "$KEY_BE" "⚙️ BE fix committed [$IMPL_TIME] — $COMMITS"
[ -n "${KEY_DB:-}" ] && bash scripts/add-jira-comment.sh "$KEY_DB" "⚙️ DB fix committed [$IMPL_TIME] — $COMMITS"
```

---

## Step 6 — QA

Spawn with `subagent_type: "team-qa"`:

> Issue fix QA: `$ARGUMENTS`. Branch: `<BRANCH>`.
> Verify the specific broken behavior is fixed. Test each layer that was changed.
> Check for regressions in adjacent features.
> Severity was <P0/P1/P2> — be proportionally thorough.
> Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# PASS:
bash scripts/add-jira-comment.sh "$EPIC_KEY" "✅ QA PASS [$QA_TIME] — docs/qa/<SLUG>.md"
[ -n "${KEY_FE:-}" ] && bash scripts/update-jira-status.sh "$KEY_FE" "Done"
[ -n "${KEY_BE:-}" ] && bash scripts/update-jira-status.sh "$KEY_BE" "Done"
[ -n "${KEY_DB:-}" ] && bash scripts/update-jira-status.sh "$KEY_DB" "Done"
# BLOCKED:
bash scripts/add-jira-comment.sh "$EPIC_KEY" "🚫 QA BLOCKED [$QA_TIME] — see docs/qa/<SLUG>.md"
```

If BLOCKED: fix and re-run QA. If P0 severity: escalate immediately before re-running.

---

## Step 7 — PR + Auto-merge + Close Epic

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
ALL_COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

cat > /tmp/devpilot-pr-body-$$.md << EOF
## Issue Fix: $ARGUMENTS

**Severity:** <P0/P1/P2>
**Root cause:** <hypothesis confirmed or revised>
**Layers fixed:** <frontend / backend / DB>
**Sub-tasks:** ${KEY_FE:-—} · ${KEY_BE:-—} · ${KEY_DB:-—}
**QA:** PASS — docs/qa/<SLUG>.md

Commits: $ALL_COMMITS
EOF

PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$EPIC_KEY: fix: <issue summary>" /tmp/devpilot-pr-body-$$.md)
if [ $? -eq 0 ]; then
  # Per-layer model summary appended to the issue BEFORE it closes.
  DEVPILOT_ENGINES="frontend: $ENG_FE${IMPL_MODEL_FE:+ ($IMPL_MODEL_FE)}; backend: $ENG_BE${IMPL_MODEL_BE:+ ($IMPL_MODEL_BE)}; db: $ENG_DB${IMPL_MODEL_DB:+ ($IMPL_MODEL_DB)}; integration: $ENG_INT${IMPL_MODEL_INT:+ ($IMPL_MODEL_INT)}" \
    bash scripts/run-summary.sh "$EPIC_KEY" "$SLUG" "<root cause / what changed>" "QA: PASS" "$BASE_BRANCH" --post
  bash scripts/update-jira-status.sh "$EPIC_KEY" "Done"
  bash scripts/add-jira-comment.sh "$EPIC_KEY" "✅ Merged [$END_TIME]
PR: $PR_URL
Duration: $START_TIME → $END_TIME
→ Promote: /binaa-sit <version>"
else
  bash scripts/update-jira-status.sh "$EPIC_KEY" "In Review"
  echo "⚠️  Merge not completed automatically — finish it at: $PR_URL"
fi

# Final checkpoint update
bash scripts/checkpoint.sh update "$EPIC_KEY" phase_completed "done"
```

---

## Final Output — DONE Block

Post the DONE block to Jira, then display it:

```bash
bash scripts/add-jira-comment.sh "$EPIC_KEY" "✅ DONE — Issue resolved, merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $ALL_COMMITS
Duration: $START_TIME → $END_TIME

What was fixed:
• Root cause: <confirmed root cause>
• FE: <what changed>
• BE: <what changed>

Task log: docs/tasks/${EPIC_KEY}.md
→ Promote to SIT: /binaa-sit <version>"
```

Then output this block exactly, filled in with real values:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  ISSUE RESOLVED — Merged into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Epic:    <EPIC_KEY> → Done
🎫  Sub-tasks: <KEY_FE> · <KEY_BE> · <KEY_DB> → Done
🔀  Merged:  <PR URL> → <BASE_BRANCH>
⏱  Time:    <START_TIME> → <END_TIME>

📦  What was fixed:
    • Root cause: <confirmed root cause>
    • FE: <what changed>
    • BE: <what changed>
    • DB: <what changed>

🔗  DEV deploys automatically (~5 min after CI passes)
──────────────────────────────────────────────────────
🚀  Promote when DEV is verified:
    1. DEV looks good?   → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
