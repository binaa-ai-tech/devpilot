# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.devpilot/rules.md` throughout.

---

## Step 0 — Load config and capture start time

1. Read `project.config.md` — extract and announce:
   ```
   Project:        <project_name>
   Base branch:    <base_branch>
   Coding engine:  <engines.coding>
   Runner:         <engines.runner>
   Fallback:       <engines.fallback>
   Coding models (<engines.coding>):
     Frontend:    <coding_models.<engine>.frontend>
     Backend:     <coding_models.<engine>.backend>
     DB:          <coding_models.<engine>.db>
     Integration: <coding_models.<engine>.integration>
   Active agents: <list>
   ```
   **If project_name is missing or this looks like the wrong project, stop and tell the user to open the correct project in Claude Code.**

2. Capture start time:
   ```bash
   START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   ```

3. Set `BASE_BRANCH`:
   ```bash
   BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
   ```

4. Resolve the engine + model **per layer**. `scripts/resolve-engine.sh` is the
   single source of truth — it applies the Claude-entry coupling (runner=claude ⇒
   all layers run on Claude) and any `layer_overrides` from `project.config.md`.
   ```bash
   FALLBACK_ENGINE=$(grep -A 5 '^engines:' project.config.md | grep 'fallback:' | head -1 | sed 's/.*fallback:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

   _resolve() {  # $1 = layer name → sets ENG_<L> + MODEL_<L>
     eval "$(bash scripts/resolve-engine.sh layer "$1")"
     [ -z "$LAYER_ENGINE" ] && LAYER_ENGINE="claude"
     echo "$LAYER_ENGINE|$LAYER_MODEL"
   }
   IFS='|' read -r ENG_FE  IMPL_MODEL_FE  <<< "$(_resolve frontend)"
   IFS='|' read -r ENG_BE  IMPL_MODEL_BE  <<< "$(_resolve backend)"
   IFS='|' read -r ENG_DB  IMPL_MODEL_DB  <<< "$(_resolve db)"
   IFS='|' read -r ENG_INT IMPL_MODEL_INT <<< "$(_resolve integration)"

   # Run mode (`$RUN_MODE` from `/ceo` Step 0) is the user's explicit
   # "pre-configuration" — an explicit flag forces ONE engine across ALL layers,
   # overriding per-layer coupling + overrides. No flag ⇒ keep per-layer values.
   case "$RUN_MODE" in
     claude|opencode|antigravity)
       ENG_FE="$RUN_MODE"; ENG_BE="$RUN_MODE"; ENG_DB="$RUN_MODE"; ENG_INT="$RUN_MODE"
       _m() { grep -A 20 "^  ${RUN_MODE}:" project.config.md | grep "    ${1}:" | head -1 | sed "s/.*${1}:[[:space:]]*//" | tr -d '"'; }
       IMPL_MODEL_FE=$(_m frontend); IMPL_MODEL_BE=$(_m backend); IMPL_MODEL_DB=$(_m db); IMPL_MODEL_INT=$(_m integration) ;;
     max)
       ENG_FE="claude"; ENG_BE="claude"; ENG_DB="claude"; ENG_INT="claude" ;;  # max judges both; Claude is candidate A
   esac
   echo "Run mode: ${RUN_MODE:-per-layer} · FE=$ENG_FE BE=$ENG_BE DB=$ENG_DB INT=$ENG_INT"
   ```
   When invoked directly (not via `/ceo`), `$RUN_MODE` is unset and each layer
   uses its resolved engine — Claude-Code entry keeps everything on Claude unless
   `layer_overrides` route a specific layer elsewhere.

5. Read `.devpilot/skills/get-shit-done.md`, `.devpilot/skills/architecture-guard.md`, `.devpilot/skills/self-heal.md`

6. **Pre-flight scan** — enrich the task with local signal (git diffs, recent
   commits, in-scope files) before the BA writes requirements. Read-only, no LLM:
   ```bash
   SLUG="<derived from $ARGUMENTS — lowercase, hyphens, max 5 words>"
   PREFLIGHT=$(bash scripts/preflight-scan.sh "$ARGUMENTS" "$SLUG")
   ```
   Pass `docs/preflight/<SLUG>.md` to the BA in Phase 1 as additional context.

Set `ACTIVE_AGENTS` = agents where `enabled: true` in project.config.md.

---

## Phase 1 — BA: Autonomous Requirements

**Adopt the Business Analyst persona.** Read `.devpilot/prompts/team/ba-agent.md`.

**Ensure the project index is fresh:**
```bash
if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
  echo "Project index is fresh — skipping regeneration"
else
  bash scripts/generate-project-index.sh
fi
```
Read `docs/project-index.md`. Use it to scope all file reading (3-8 files max).

1. Analyze the task: `$ARGUMENTS`
2. Read the existing codebase to understand context — scan relevant files, routes, components, services
3. Write `docs/requirements/<task-slug>.md` using `.devpilot/templates/team/requirements.md`
   - Document all assumptions made (no clarifying questions — follow rules.md)
   - Include user story, acceptance criteria, scope, data/API changes, edge cases
4. Write `docs/domain-models/<task-slug>.md` using `.devpilot/templates/team/domain-model.md`
5. Count the acceptance criteria. Save as `AC_COUNT`.
6. Announce: "✅ BA Phase complete. Requirements at `docs/requirements/<slug>.md`. AC count: <AC_COUNT>"

**Do not stop or ask questions.**

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Read `docs/requirements/<slug>.md`

2. **Determine ticket structure:**
   - **Simple** (AC_COUNT ≤ 5 AND 1-2 agents): ONE Task ticket
   - **Complex** (AC_COUNT > 5 OR 3+ agents): Epic + one child Task per agent

3. **Create ticket(s) and move to In Progress:**

   **Simple:**
   ```bash
   KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "<user story, first 200 chars>" "Task")
   bash scripts/update-jira-status.sh "$KEY" "In Progress"
   ```

   **Complex:**
   ```bash
   EPIC_KEY=$(bash scripts/create-jira-epic.sh "<feature name>" "<user story, first 300 chars>")
   bash scripts/update-jira-status.sh "$EPIC_KEY" "In Progress"
   KEY_FE=$(bash scripts/create-jira-epic.sh "[Frontend] <summary>" "<frontend ACs>" "$EPIC_KEY")
   KEY_BE=$(bash scripts/create-jira-epic.sh "[Backend] <summary>" "<backend ACs>" "$EPIC_KEY")
   bash scripts/update-jira-status.sh "$KEY_FE" "In Progress"
   bash scripts/update-jira-status.sh "$KEY_BE" "In Progress"
   KEY="$EPIC_KEY"
   ```

4. **Log start to Jira (human-readable):**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "🚀 Task started
Command: /ceo \"$ARGUMENTS\"
Branch: feature/$(echo $KEY | tr '[:upper:]' '[:lower:]')-<slug>
Started: $START_TIME
Engines: FE=$ENG_FE BE=$ENG_BE DB=$ENG_DB INT=$ENG_INT
Agents: <list of active agents>"
   ```

5. **Update Jira description:**
   ```bash
   USER_STORY=$(grep -A 20 "## User Story" docs/requirements/<slug>.md | head -20)
   bash scripts/update-jira-description.sh "$KEY" "User Story: $USER_STORY | Task: $ARGUMENTS"
   ```

6. **Create feature branch:**
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   BRANCH=$(git branch --show-current)
   ```

7. Determine scope: frontend? backend? DB? integration?
   Cross-check against `project.config.md → agents`.

8. Write `docs/plans/<slug>.md` using `.devpilot/templates/team/implementation-plan.md`

9. **Initialize task log:**
   ```bash
   mkdir -p docs/tasks
   cat > "docs/tasks/${KEY}.md" << EOF
   ---
   key: $KEY
   slug: <slug>
   command: /ceo
   branch: $BRANCH
   base_branch: $BASE_BRANCH
   started: $START_TIME
   status: in-progress
   ---

   ## Task
   $ARGUMENTS

   ## Plan
   docs/plans/<slug>.md

   ## Timeline
   | Time | Phase | Notes |
   |------|-------|-------|
   | $START_TIME | Started | Ticket: $KEY · Branch: $BRANCH |

   ## Commits
   (updated at completion)

   ## Result
   (updated at completion)
   EOF
   ```

10. **Log plan complete to the task log** (routine progress → repo, not Jira, per
    core-rules #11):
    ```bash
    PLAN_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    printf -- '- %s — plan complete: docs/plans/<slug>.md, scope <…>, %s ACs\n' \
      "$PLAN_TIME" "$AC_COUNT" >> "docs/tasks/${KEY}.md"
    ```

11. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

The per-layer engines resolved in Phase 0 (`$ENG_FE/$ENG_BE/$ENG_DB/$ENG_INT`)
determine how each layer's code is written. Layers can be mixed (e.g. backend on
opencode via a `layer_overrides`, everything else on Claude):

| Layer engine | Follow |
|--------------|--------|
| `claude` | **### Engine: `claude`** below — spawn via the Agent tool |
| `opencode` / `antigravity` | **### Engine: `opencode` or `antigravity`** below — run that layer via Bash |
| `$RUN_MODE = max` | **### Mode: `max`** below — race both engines and merge the winner |

When `$RUN_MODE` is an explicit flag, all four `$ENG_*` are forced to the same
engine, so a single section applies. With no flag, route each layer by its own engine.

> **Token discipline:** brief each agent with a *compact* context (see
> `.devpilot/skills/compact-context.md`) — the acceptance criteria plus the
> named files to touch — not raw `docs/requirements` / `docs/plans` file dumps.

---

### Engine: `claude`

Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both needed.

**Frontend Agent** (if `agents.frontend.enabled: true` AND frontend work identified)

Spawn with `subagent_type: "team-frontend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Implement all frontend work per the plan. Read `.devpilot/skills/self-heal.md`. Run lint + build + tests. Commit with conventional commit message. Report what you built in 3 bullets.

**Backend Agent** (if `agents.backend.enabled: true` AND backend work identified)

Spawn with `subagent_type: "team-backend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Implement all backend work per the plan. Read `.devpilot/skills/self-heal.md`. Run build + tests. Commit with conventional commit message. Report what you built in 3 bullets.

**DB Agent** (if `agents.db.enabled: true` AND DB schema/migration work identified)

Spawn with `subagent_type: "team-backend"`:

> Task: DB changes for `[task description]`. Branch: `<branch>`. Implement all migrations per the plan. Run migration tests. Commit.

**Integration Agent** (if `agents.integration.enabled: true` AND integration work identified)

Spawn with `subagent_type: "team-backend"`:

> Task: Integration work for `[task description]`. Branch: `<branch>`. Implement all integration work per the plan. Run tests. Commit.

Wait for all agents to complete.

**After implementation:**
```bash
IMPL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')
# Routine progress → task log, not Jira (core-rules #11).
printf -- '- %s — implementation complete (%s); agents: <list>\n' \
  "$IMPL_TIME" "$COMMITS" >> "docs/tasks/${KEY}.md"
```

**If any agent FAILED:**
1. Write `docs/implementation/<slug>-<agent>-brief.md` with full context of remaining work
2. Run the brief directly via Bash tool — do NOT output a HANDOFF block
3. Stop — do not proceed to Phase 4

---

### Engine: `opencode` or `antigravity`

⚠️ **CRITICAL: Use the Bash tool to execute the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**

Write one implementation brief per agent at `docs/implementation/<slug>-<agent>.md`:

```markdown
# Implementation Brief — <Agent> — <slug>

## Task
<original task description>

## Branch
<feature branch> — already created, check it out first:
git checkout <branch>

## What to build
Read the full plan: docs/plans/<slug>.md
Read the full requirements: docs/requirements/<slug>.md

## Your scope (<Agent> only)
<paste the relevant section from the plan for this agent>

## Acceptance criteria for this agent
<paste the ACs this agent owns>

## Tech stack rules
Read .devpilot/rules.md before writing any code.

## Definition of Done
- [ ] All ACs above are met
- [ ] Lint passes
- [ ] Build passes
- [ ] Tests pass
- [ ] Committed with: <feat|fix>(<slug>): <description>
```

Then execute each brief directly via bash — run sequentially, block until each
completes. Each layer uses **its own resolved engine** (`$ENG_FE/$ENG_BE/$ENG_DB/$ENG_INT`).
A layer that resolved to `claude` (e.g. under Claude-entry coupling, or a layer
not covered by a `layer_overrides`) is **not** run here — spawn it via the Agent
tool under **### Engine: `claude`** instead.

```bash
# Frontend (if in scope and routed off-Claude)
if [ -f "docs/implementation/<slug>-frontend.md" ] && [ "$ENG_FE" != "claude" ]; then
  $ENG_FE --model "$IMPL_MODEL_FE" < docs/implementation/<slug>-frontend.md
fi

# Backend (if in scope and routed off-Claude)
if [ -f "docs/implementation/<slug>-backend.md" ] && [ "$ENG_BE" != "claude" ]; then
  $ENG_BE --model "$IMPL_MODEL_BE" < docs/implementation/<slug>-backend.md
fi

# DB (if in scope and routed off-Claude)
if [ -f "docs/implementation/<slug>-db.md" ] && [ "$ENG_DB" != "claude" ]; then
  $ENG_DB --model "$IMPL_MODEL_DB" < docs/implementation/<slug>-db.md
fi

# Integration (if in scope and routed off-Claude)
if [ -f "docs/implementation/<slug>-integration.md" ] && [ "$ENG_INT" != "claude" ]; then
  $ENG_INT --model "$IMPL_MODEL_INT" < docs/implementation/<slug>-integration.md
fi
```

Do NOT output a handoff block. Do NOT stop. Proceed directly to Phase 4 (QA) once all commands exit 0.

---

### Mode: `max` — dual-engine race (Claude + opencode)

Implement the plan **twice** — once with Claude subagents, once with opencode —
on isolated branches, then judge and merge the better result.

**Pre-check:** if `command -v opencode` is missing, skip the race, run the
`### Engine: claude` path on `$BRANCH`, announce
"⚠️ max mode: opencode not installed — ran claude-only", and continue to Phase 4.

1. **Set a common starting point** — commit the docs so both candidates diverge
   from the same tree:
   ```bash
   git add docs/ && git commit -m "docs(<slug>): requirements + plan (max baseline)" || true
   CAND_CLAUDE="${BRANCH}-claude"
   CAND_OC="${BRANCH}-opencode"
   git branch "$CAND_CLAUDE"
   git branch "$CAND_OC"
   ```

2. **Candidate A — Claude:**
   ```bash
   git checkout "$CAND_CLAUDE"
   ```
   Spawn the developer agents exactly as in **### Engine: `claude`** above.
   Wait for completion and confirm the work is committed on this branch.

3. **Candidate B — opencode:**
   ```bash
   git checkout "$CAND_OC"
   ```
   Write the per-agent briefs and run opencode exactly as in
   **### Engine: `opencode` or `antigravity`** above, using the `opencode`
   models (`IMPL_MODEL_*`). Confirm the work is committed on this branch.

4. **Judge — pick the winner.** For each candidate, check it out, run the
   stack-appropriate build + tests, and capture the result:
   ```bash
   for C in "$CAND_CLAUDE" "$CAND_OC"; do
     git checkout "$C"
     echo "=== $C ==="; git diff "$BRANCH".."$C" --stat
     # run build + tests for the stack; note PASS/FAIL
   done
   ```
   As **Team Lead**, compare both against the acceptance criteria and
   `.devpilot/rules.md`, in this priority order:
   1. **Correctness** — meets every acceptance criterion.
   2. **Build + tests green** — a failing build/test loses outright.
   3. **Rule adherence + smaller, cleaner diff** — tiebreaker.
   Choose `WINNER` (`claude` or `opencode`) and write a one-paragraph rationale.

5. **Merge the winner, discard the loser:**
   ```bash
   git checkout "$BRANCH"
   git merge --squash "${BRANCH}-${WINNER}"
   git commit -m "feat(<slug>): implement via max mode (winner: ${WINNER})"
   git branch -D "$CAND_CLAUDE" "$CAND_OC"
   ```

6. **Log the outcome:**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "🏁 Max mode — winner: ${WINNER}
Rationale: <one-line rationale>
Both candidates built + tested; losing branch discarded."
   ```

Continue to Phase 4 (QA) on `$BRANCH`.

---

## Phase 4 — QA: Testing

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict: PASS or BLOCKED.

Wait for QA agent to complete.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# PASS: routine — record in the task log, not Jira (core-rules #11).
printf -- '- %s — QA PASS, all %s ACs verified (docs/qa/<slug>.md)\n' "$QA_TIME" "$AC_COUNT" >> "docs/tasks/${KEY}.md"
# BLOCKED: an exception — post it to Jira.
bash scripts/add-jira-comment.sh "$KEY" "🚫 QA BLOCKED [$QA_TIME] — See docs/qa/<slug>.md for failures"
```

If BLOCKED: fix the issue (spawn the relevant agent again), then re-run QA.

---

## Phase 5 — Team Lead: Review & PR

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-review.md`.

1. **Review gate — must pass before any PR is opened.** Run `git diff <BASE_BRANCH>...HEAD`
   and review it against `.devpilot/skills/code-review.md` and `.devpilot/skills/security-scan.md`
   (and `.devpilot/rules.md`):
   - Tag findings 🔴 BLOCKER / 🟡 SHOULD / 🟢 NIT.
   - Run the dependency audit: `bash scripts/audit.sh` — treat new high/critical
     vulnerabilities as 🔴.
   - **Any 🔴 → fix it (re-spawn the owning agent), then re-review.** Never open a PR
     with an open 🔴 or a BLOCKED QA verdict.
   - Record the verdict (APPROVED / CHANGES REQUESTED) in the review report.
2. Check `docs/qa/<slug>.md` — if BLOCKED, resolve before continuing
3. Write `docs/reviews/<slug>.md` using `.devpilot/templates/team/review-report.md`
4. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<slug>): add requirements, plan, qa, and review docs"
   ```
5. **Create PR + auto-merge into develop** (tool-agnostic — uses `gh` if present,
   else prints a compare URL / GitHub-MCP fallback):
   ```bash
   # Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
   PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$KEY: <description>" "docs/reviews/<slug>.md")
   if [ $? -eq 0 ]; then
     # Run summary — records what changed + the engine/model used per layer to a
     # local summary file. No --post: the single DONE comment (Final Output) is
     # the one Jira summary, per core-rules #11.
     DEVPILOT_ENGINES="frontend: $ENG_FE${IMPL_MODEL_FE:+ ($IMPL_MODEL_FE)}; backend: $ENG_BE${IMPL_MODEL_BE:+ ($IMPL_MODEL_BE)}; db: $ENG_DB${IMPL_MODEL_DB:+ ($IMPL_MODEL_DB)}; integration: $ENG_INT${IMPL_MODEL_INT:+ ($IMPL_MODEL_INT)}" \
       bash scripts/run-summary.sh "$KEY" "<slug>" "<what changed>" "QA: PASS — all $AC_COUNT ACs" "$BASE_BRANCH"
     bash scripts/update-jira-status.sh "$KEY" "Done"
   else
     bash scripts/update-jira-status.sh "$KEY" "In Review"
     echo "⚠️  Merge not completed automatically — finish it at: $PR_URL"
   fi
   ```

6. **Capture final state:**
   ```bash
   END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   ALL_COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | head -10)
   COMMIT_HASHES=$(echo "$ALL_COMMITS" | awk '{print $1}' | tr '\n' ' ')
   ```

7. **(No interim Jira comment here.)** Per core-rules #11, the only summary
   posted to Jira is the single DONE block in *Final Output* below — posting a
   "merged" comment here as well would duplicate it. The merge facts are captured
   in the task log (next step) and the PR.

8. **Finalize task log:**
   ```bash
   cat >> "docs/tasks/${KEY}.md" << EOF

   ## Result (merged: $END_TIME)
   - PR: $PR_URL (merged into $BASE_BRANCH)
   - Jira: $KEY → Done
   - Commits: $COMMIT_HASHES

   ### What was built
   <3-5 bullet summary of what each agent built>
   EOF
   ```

---

## Final Output — DONE Block

Post the DONE block to Jira, then display it:

```bash
bash scripts/add-jira-comment.sh "$KEY" "✅ DONE — Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $COMMIT_HASHES
Duration: $START_TIME → $END_TIME

What was built:
• <bullet 1>
• <bullet 2>
• <bullet 3>

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
🔖  Commits: <hash1> · <hash2> · <hash3>

📦  What was built:
    • <bullet 1>
    • <bullet 2>
    • <bullet 3>

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote to production when ready:
    1. DEV ready?        → /binaa-sit <version>
       Tip: git tag --sort=-version:refname | head -1
            → features: bump MINOR (1.0.0 → 1.1.0)
            → bug fixes: bump PATCH (1.0.0 → 1.0.1)
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
         ↑ Production PR opens here — requires your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
