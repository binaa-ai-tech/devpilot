# Skill: Context Compaction

Apply this skill before passing context between phases to avoid bloating the token budget
with raw document dumps. Instead of passing full files, pass a structured compact summary.

---

## When to Compact

Compact context before:
- Spawning an implementation agent (Phase 3)
- Spawning a QA agent (Phase 4)
- Writing a fallback prompt for an external engine
- Any handoff between tools (Claude → opencode, Claude → antigravity)

Do NOT compact:
- When reading files to understand the codebase (read them fully)
- When the original document is short (< 80 lines) — pass it directly

---

## Compact Summary Format

Instead of dumping `docs/requirements/<slug>.md` directly, write a compact block:

```
## COMPACT CONTEXT — <slug>
Generated: <timestamp>
From: docs/requirements/<slug>.md + docs/plans/<slug>.md

### Task
<original task description — 1 sentence>

### Acceptance Criteria (<N> total)
1. <AC 1>
2. <AC 2>
...
<N>. <AC N>
(Include ALL ACs — these are the contract)

### Scope
Frontend: <yes/no — which files/components>
Backend:  <yes/no — which endpoints/services>
DB:       <yes/no — which tables/migrations>

### Key Decisions (from plan)
- <architectural decision 1>
- <architectural decision 2>
(Only non-obvious decisions that affect implementation)

### Files to Touch
- <file 1> — <what to change>
- <file 2> — <what to change>
(Copy from plan exactly — these are the instructions)

### What NOT to touch
- <file or area> — <why it's out of scope>

### Already Done (if resuming)
- <phase or agent> — committed <hash>: <what was built>
```

---

## How to Use in Agent Spawns

Instead of:
```
> Requirements: docs/requirements/<slug>.md. Plan: docs/plans/<slug>.md. Branch: <branch>. ...
```

Write the compact context inline:
```
> ## COMPACT CONTEXT — <slug>
> Task: <1 sentence>
> ACs: 1. <ac1>  2. <ac2>  3. <ac3>
> Your scope: <frontend/backend/DB>
> Files to touch: <file1> (change X), <file2> (change Y)
> Branch: <branch>
> Rules: .devpilot/rules.md
> Self-heal: .devpilot/skills/self-heal.md
```

---

## Compaction Rules

1. **ACs are sacred — never omit them.** Everything else can be summarized.
2. **File list from the plan is the implementation contract** — include it verbatim.
3. **Remove prose explanations** from requirements — keep only the testable criteria.
4. **Max 60 lines per compact block.** If you cannot fit it, split into per-agent compacts.
5. **When resuming**, include the "Already Done" section so the agent doesn't redo work.

---

## Token Budget Guidance

| Phase | Target token budget for context |
|---|---|
| BA → produces requirements | Reads raw code (necessary) |
| Lead → produces plan | Reads requirements (necessary) |
| Implementation agent | Compact context only — **not raw docs** |
| QA agent | Compact context + compact diff summary |
| Fallback prompt | Compact context + "already done" section |
| Resume state | Checkpoint JSON (structured, not prose) |
