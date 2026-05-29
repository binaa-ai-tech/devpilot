# /ceo-fix — Fast Bug Fix

Bug: **$ARGUMENTS**

Team Lead scopes the fix directly. No BA, no formal requirements, no QA docs.
Implement → commit → PR. Done.

---

## Step 0 — Load config

Read `project.config.md`. Extract engine settings and per-agent models.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

# Read engines block (lines under "engines:")
IMPL_ENGINE=$(grep -A 10 '^engines:' project.config.md | grep '^\s*coding:' | head -1 | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
[ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"

# Read per-agent models from the active coding engine's section
_model() {
  grep -A 20 "^  ${IMPL_ENGINE}:" project.config.md 2>/dev/null \
    | grep "    ${1}:" | head -1 \
    | sed "s/.*${1}:[[:space:]]*//" | tr -d '"' | awk '{print $1}'
}
IMPL_MODEL_FE=$(_model frontend)
IMPL_MODEL_BE=$(_model backend)
IMPL_MODEL_DB=$(_model db)
```

Validate: if `project.config.md` is missing or `base_branch` is empty, stop and tell the user to run `bash install.sh` first.

---

## Step 0b — Pre-flight scan (context enrichment)

Tickets are often thin. Gather local signal before scoping so you infer the right
files and layer instead of guessing:

```bash
SLUG=<derive in Step 1; for now use a short slug from "$ARGUMENTS">
PREFLIGHT=$(bash scripts/preflight-scan.sh "$ARGUMENTS" "$SLUG")
```

Read `$PREFLIGHT` — use the recent history, working-tree diff, and "files likely
in scope" sections to localize the root cause faster. This is read-only signal; it
calls no LLM.

---

## Step 1 — Team Lead: Scope the fix

**Adopt Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md` and `.devpilot/skills/debug-method.md` (reproduce → localize → root cause before changing code).

1. Ensure project index is fresh:
   ```bash
   if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
     echo "Project index is fresh — skipping"
   else
     bash scripts/generate-project-index.sh
   fi
   ```
   Read `docs/project-index.md` to identify affected files.

2. Read the 2-4 most relevant source files to understand root cause.

3. Write a short scope (no file needed — keep in context):
   - Root cause: `<what is broken and why>`
   - Fix: `<exactly what to change, which files>`
   - Risk: `<any side effects>`
   - Agent: `<frontend | backend | db | integration | multiple>`

4. Derive slug: lowercase, hyphens, max 5 words from `$ARGUMENTS`
   Example: "sessions table not created" → `fix-sessions-table-not-created`

---

## Step 2 — Create Jira ticket + branch

```bash
KEY=$(bash scripts/create-jira-ticket.sh "fix: <one-line summary>" "<root cause and fix — 2 sentences>" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"

TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Log start:
```bash
bash scripts/add-jira-comment.sh "$KEY" "🚀 Bug fix started [$START_TIME]
Command: /ceo-fix \"$ARGUMENTS\"
Branch: $BRANCH
Root cause: <root cause>
Fix: <what will be changed>"
```

Initialize task log:
```bash
mkdir -p docs/tasks
cat > "docs/tasks/${KEY}.md" << EOF
---
key: $KEY
slug: <SLUG>
command: /ceo-fix
branch: $BRANCH
base_branch: $BASE_BRANCH
started: $START_TIME
status: in-progress
---

## Bug
$ARGUMENTS

## Root Cause
<root cause>

## Fix
<what was changed>

## Timeline
| Time | Event |
|------|-------|
| $START_TIME | Started · Branch: $BRANCH |

## Commits
(updated at completion)
EOF
```

---

## Step 3 — Implementation

Determine which agent owns the fix based on scope analysis in Step 1.
Spawn only the relevant agent(s) — **do not spawn agents that have no work**.

### Engine: `claude`

**Backend fix** → spawn `subagent_type: "team-backend"`:
> Bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Root cause: `<root cause>`. Fix: `<exact change>`. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Make only the minimal required change. Run build + tests. Commit with `fix(<scope>): <description>`. Report the commit hash and what changed.

**Frontend fix** → spawn `subagent_type: "team-frontend"`:
> Bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Root cause: `<root cause>`. Fix: `<exact change>`. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Make only the minimal required change. Run lint + build. Commit with `fix(<scope>): <description>`. Report the commit hash and what changed.

**DB fix** → spawn `subagent_type: "team-backend"`:
> DB bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Fix: `<exact migration or query change>`. Minimal change only. Commit. Report hash.

### Engine: `opencode`

⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**

Write `docs/implementation/<SLUG>-<agent>.md` (minimal brief — root cause + exact fix only).
Then execute directly via bash — block until complete:

```bash
$IMPL_ENGINE --model "$IMPL_MODEL_BE" < "docs/implementation/${SLUG}-backend.md"
# or frontend if fix is UI-only:
# $IMPL_ENGINE --model "$IMPL_MODEL_FE" < "docs/implementation/${SLUG}-frontend.md"
```

Do NOT output a handoff block. Do NOT stop. Proceed directly to Step 4 once the command exits 0.

---

## Step 4 — Implementation verify + log

After agent completes:
```bash
git log ${BASE_BRANCH}..HEAD --oneline   # confirm commit exists
IMPL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | tr '\n' ' ')
# Process-logging policy (core-rules #11): routine progress goes to the task log,
# not Jira. Jira gets only the start comment and the final DONE summary.
printf -- '- %s — fix implemented (%s)\n' "$IMPL_TIME" "$COMMITS" >> "docs/tasks/${KEY}.md"
```

---

## Step 5 — QA

Spawn with `subagent_type: "team-qa"`:

> Bug fix QA for `$ARGUMENTS`. Branch: `<BRANCH>`. Verify the fix works correctly, the broken behavior is resolved, and no regressions introduced. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# PASS: record in the task log only (routine — not posted to Jira).
printf -- '- %s — QA PASS, fix verified (docs/qa/<SLUG>.md)\n' "$QA_TIME" >> "docs/tasks/${KEY}.md"
# BLOCKED: an exception — post it to Jira.
bash scripts/add-jira-comment.sh "$KEY" "🚫 QA BLOCKED [$QA_TIME] — see docs/qa/<SLUG>.md"
```

If BLOCKED: fix the issue, then re-run QA.

---

## Step 6 — Create PR + auto-merge into develop

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
ALL_COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')

cat > /tmp/devpilot-pr-body-$$.md << EOF
## Bug Fix: $ARGUMENTS

**Root cause:** <root cause>
**Fix:** <what changed>
**Risk:** <side effects or none>
**QA:** PASS — docs/qa/<SLUG>.md

Commits: $ALL_COMMITS
EOF

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$KEY: fix: <summary>" /tmp/devpilot-pr-body-$$.md)
if [ $? -eq 0 ]; then
  # Generate an execution summary and append it to the ticket. The ticket only
  # moves to Done AFTER the merge succeeds and the summary is posted — until
  # then it stays In Progress (set in Step 2).
  bash scripts/run-summary.sh "$KEY" "<SLUG>" "<root cause>" "QA: PASS" "$BASE_BRANCH"
  bash scripts/update-jira-status.sh "$KEY" "Done"
  # The single DONE summary comment is posted below (Final Output). No separate
  # "merged" comment here — it would duplicate the DONE block (core-rules #11).
else
  bash scripts/update-jira-status.sh "$KEY" "In Review"
  echo "⚠️  Merge not completed automatically — finish it at: $PR_URL"
fi
```

Update task log:
```bash
cat >> "docs/tasks/${KEY}.md" << EOF

## Result (merged: $END_TIME)
- PR: $PR_URL (merged into $BASE_BRANCH)
- Jira: $KEY → Done
- Commits: $ALL_COMMITS
EOF
```

---

## Final Output — DONE Block

Post the DONE block to Jira, then display it:

```bash
bash scripts/add-jira-comment.sh "$KEY" "✅ DONE — Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $ALL_COMMITS
Duration: $START_TIME → $END_TIME

What was fixed:
• Root cause: <root cause>
• Changed: <files/what changed>
• QA: PASS

Task log: docs/tasks/${KEY}.md
→ Promote to SIT: /binaa-sit <version>"
```

Then output this block exactly, filled in with real values:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Merged into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Jira:    <KEY> → Done
🔀  Merged:  <PR URL> → <BASE_BRANCH>
⏱  Time:    <START_TIME> → <END_TIME>
🔖  Commits: <hash1> · <hash2>

📦  What was fixed:
    • Root cause: <root cause>
    • Changed: <files/what changed>
    • QA: PASS

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes (~5 min)
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote to production when ready:
    1. DEV ready?        → /binaa-sit <version>
       Tip: bug fixes bump PATCH (1.0.0 → 1.0.1)
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
         ↑ Production PR opens here — requires your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
