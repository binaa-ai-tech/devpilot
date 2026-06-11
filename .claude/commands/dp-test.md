# /dp-test — Design test cases, write the tests, run them

Input: **$ARGUMENTS** — a Story key/slug, a PR number, `diff` (current branch vs
base), or empty = the latest in-progress task. A leading `perf` adds a
performance-testing pass (e.g. `/dp-test perf PROJ-12`).

QA on demand: derive a test-case matrix from the acceptance criteria, write the
missing tests, run the suite, and report gaps that are real bugs. No new branch,
no PR — tests are committed to the current/PR branch.

---

## Step 0 — Resolve scope + engine

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
# QA is lite-tier work unless the diff is architectural
eval "$(bash scripts/resolve-engine.sh suggest "$ARGUMENTS")"
```

Resolve what to test:
- **Story key/slug** → read `docs/requirements/<slug>.md` (ACs) + `docs/plans/<slug>.md`.
- **PR number** → `gh pr checkout <n>`; scope = the PR diff.
- **`diff` / empty** → `git diff ${BASE_BRANCH}...HEAD --name-only`; ACs from the
  latest task in `docs/tasks/`. With no ACs anywhere, derive cases from the
  changed behavior itself and say so in the report.

## Step 1 — Design the cases (paper before code)

Spawn `subagent_type: "team-qa"`:
> Scope: `<resolved scope>`. Read `.devpilot/skills/test-case-design.md` and derive
> the test-case matrix per AC (happy / boundary / negative / state, P0–P2,
> traceability). Write the matrix into `docs/qa/<slug>.md` BEFORE writing test code.

## Step 2 — Write the missing tests

Same agent, continuing:
> For each case with no covering test, write one per `.devpilot/skills/test-strategy.md`
> (right pyramid layer, behavior not internals). Load `.devpilot/skills/e2e-testing.md`
> only if a critical journey is in scope. If the input started with `perf` or an AC
> carries a performance requirement, load `.devpilot/skills/performance-testing.md`
> and add/run the budgeted perf script under `perf/`.

## Step 3 — Run + verdict

> Run the full suite; apply `.devpilot/skills/self-heal.md` on failures (3 attempts,
> test-code fixes only — an implementation bug is a 🔴 BLOCKER finding, never a
> weakened assertion). Commit tests with `test(<slug>): <what>`. Finish
> `docs/qa/<slug>.md` with the matrix, coverage added, and PASS / BLOCKED per AC.

## Report

```
🧪 /dp-test — <scope>
Cases designed:  <n> (P0: <n> · P1: <n> · P2 deferred: <n>)
Tests added:     <n> files · suite: ✅ <passed>/<total>  (or ❌ failing list)
Perf:            <budget table or "not in scope">
Blockers:        <real bugs found, or none>
QA report:       docs/qa/<slug>.md
```
