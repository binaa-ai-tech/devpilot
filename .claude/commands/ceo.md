# /ceo — CEO Task Intake

Task: **$ARGUMENTS**

You are the AI development team. A task has been submitted.
Execute it fully. The only required human interactions are:
1. Test on DEV and decide when to promote each stage
2. Run opencode if Claude limit fallback is triggered (prompted automatically)

**Engine modes** — an optional leading flag selects how the work runs:
- `/ceo --claude <task>`   — all phases + coding on Claude subagents
- `/ceo --opencode <task>` — Claude orchestrates; opencode writes all code
- `/ceo --max <task>`      — race **both** engines, judge, merge the winner
- no flag                  — uses `engines.coding` from `project.config.md`

---

## Step 0 — Resolve run mode (engine selection)

Parse the optional leading flag and strip it from the task:

```bash
eval "$(bash scripts/run-mode.sh "$ARGUMENTS")"
# $RUN_MODE = claude | opencode | max   ·   $TASK = task with the flag removed
echo "Run mode: $RUN_MODE"
```

Use `$TASK` (not `$ARGUMENTS`) as the task description from here on, and carry
`$RUN_MODE` into the full-team flow. Announce: "🎛  Run mode: `<RUN_MODE>`".

---

## Step 1 — Read project config

Read `project.config.md` — note base_branch, active agents, model routing.

---

## Step 2 — Classify the task

| Type | Signals | Mode |
|------|---------|------|
| **HOTFIX** | "down", "P0", "production broken", "critical", "urgent", "users can't" | Expedited (skip BA) |
| **BUG** | "fix", "broken", "not working", "error", "wrong", "failing", "crash" | Full team (bug framing) |
| **FEATURE** | Everything else — new capability, enhancement, improvement | Full team (feature framing) |

---

## Step 2b — Route by size (token-lean)

After the type, size-classify so small work skips the heavy 5-phase flow and
its five docs. Use `scripts/scope.sh "$TASK"` to gauge how many files/layers
are involved.

| Size | Signal | Route |
|------|--------|-------|
| **Trivial** | one file; copy / text / config tweak; no real logic | run `.claude/commands/ceo-fix.md` |
| **Single-layer** | clearly one of FE / BE / DB and self-contained | run `.claude/commands/ceo-subdomain.md` with that scope |
| **Multi-layer / large** | spans layers, or > ~5 acceptance criteria | full team flow below |

Prefer the lighter route when in doubt; escalate to the full flow only if the
lighter track uncovers cross-layer work. HOTFIX always uses the expedited flow.

---

## Feature or Bug (multi-layer / large) → Full Team Flow

Read `.claude/commands/team-task.md` and execute all 5 phases fully.
Pass `$RUN_MODE` and `$TASK` through — Phase 3 dispatches on `$RUN_MODE`
(`claude` / `opencode` / `max`).

Run all phases autonomously. Do not stop unless:
- A Claude limit triggers the fallback engine (self-heal.md handles this — see engines.fallback in project.config.md)
- A QA BLOCKED verdict requires human input

---

## Hotfix → Expedited Team Flow

Speed is critical. Skip BA and go directly to planning.

**Phase 1 — Skip (no requirements doc needed)**

**Phase 2 — Team Lead: Hotfix Planning (condensed)**

1. Read `project.config.md` → base_branch
2. Identify the deployed tag to branch from:
   ```bash
   git tag --sort=-version:refname | head -1
   ```
3. Create hotfix branch:
   ```bash
   bash scripts/git-flow.sh hotfix-start <ticket-number> <slug>
   ```
4. Write a minimal plan in `docs/plans/<slug>.md` — root cause, exact fix, affected files only

**Phase 3 — Implementation (minimal diff only)**

Resolve the engine for the broken layer (`backend` shown; use `frontend` if the
fix is FE). `resolve-engine.sh` applies the Claude-entry coupling + `layer_overrides`.
A `--claude`/`--opencode`/`--max` flag on `/ceo` (`$RUN_MODE`) forces that engine.
```bash
eval "$(bash scripts/resolve-engine.sh layer backend)"
HOTFIX_ENGINE="$LAYER_ENGINE"; HOTFIX_MODEL="$LAYER_MODEL"
case "$RUN_MODE" in claude|opencode|antigravity) HOTFIX_ENGINE="$RUN_MODE" ;; max) HOTFIX_ENGINE="claude" ;; esac
[ -z "$HOTFIX_ENGINE" ] && HOTFIX_ENGINE="claude"
```

If `$HOTFIX_ENGINE` = `opencode` or `antigravity`:
  ⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block.**
  Write `docs/implementation/<slug>-hotfix.md` with the minimal fix scope (one agent only).
  Then immediately run via Bash tool:
  ```bash
  $HOTFIX_ENGINE --model "$HOTFIX_MODEL" < "docs/implementation/<slug>-hotfix.md"
  ```
  Proceed to Phase 4 when it exits 0.

If `$HOTFIX_ENGINE` = `claude`:
  Spawn only the relevant agent (frontend OR backend — not both unless both are broken).
  Brief: minimum diff, no refactoring, no unrelated changes, follow hotfix rules in `.devpilot/rules.md`.

**Phase 4 — QA: Smoke Test**

Spawn QA agent with expedited brief:
> Hotfix for `<slug>`. Verify the specific broken behavior is fixed. Regression test the surrounding area only. PASS or BLOCKED verdict.

**Phase 5 — Review & PR**

Same as full flow but PR targets `<BASE_BRANCH>` with hotfix label.
After merge: cherry-pick or merge back into develop if it exists.

---

## Resume After External Engine Implementation

If you are running `/ceo resume`:

1. Read `docs/implementation/` — find the slug and which agents were briefed
2. Run:
   ```bash
   git status       # confirm you are on the feature branch
   git log --oneline -5   # confirm coding engine commits are present
   ```
3. Continue from **Phase 4 — QA** in team-task.md. Do not re-run Phases 1-3.
4. If the coding engine only finished some agents (not all): note which are done, brief the remaining ones,
   run each remaining brief via the Bash tool, then continue to Phase 4.

---

## CEO Report (output when all work is done)

Post to Jira first, then display:

```bash
bash scripts/add-jira-comment.sh "$KEY" "✅ DONE — Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $COMMIT_HASHES
Duration: $START_TIME → $END_TIME

What was built:
• <bullet 1>
• <bullet 2>
• <bullet 3>

→ Promote to SIT: /binaa-sit <version>"
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Ready for your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋  Jira:    <ticket URL>
🔀  PR:      <pull request URL>

📦  What was built:
    • <bullet 1>
    • <bullet 2>
    • <bullet 3>

🔗  Test on DEV:  <DEV_FRONTEND_URL from .devpilot/config.sh>
    (Live ~5 min after PR merges and CI passes)

──────────────────────────────────────────────────────
🚀  Promote when ready:

    1. DEV looks good?
       Run: /binaa-sit <version>
       Tip: git tag --sort=-version:refname | head -1
            → features: bump MINOR (1.0.0 → 1.1.0)
            → bug fixes: bump PATCH (1.0.0 → 1.0.1)

    2. SIT passed QA?
       Run: /binaa-uat

    3. UAT signed off?
       Run: /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
