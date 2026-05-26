# /ceo — CEO Task Intake

Task: **$ARGUMENTS**

You are the AI development team. A task has been submitted.
Execute it fully. The only required human interactions are:
1. Test on DEV and decide when to promote each stage
2. Run opencode if Claude limit fallback is triggered (prompted automatically)

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

## Feature or Bug → Full Team Flow

Read `.claude/commands/team-task.md` and execute all 5 phases fully.

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

Read `project.config.md → implementation.engine`.

If engine = `opencode` or `antigravity`:
  Write `docs/implementation/<slug>-hotfix.md` with the minimal fix scope (one agent only).
  Output the IMPLEMENTATION HANDOFF block exactly as in team-task.md Phase 3 (substituting the engine name).
  Stop and wait for `/ceo resume`.

If engine = `claude`:
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
   stop again with the same IMPLEMENTATION HANDOFF block, and wait for `/ceo resume` again.

---

## CEO Report (output when all work is done)

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
