# /dp-test — Design test cases, write the tests, run them

Input: **$ARGUMENTS** — a Story key/slug, a PR number, `diff` (current branch vs
base), or empty = the latest in-progress task. An optional leading mode:
- `ui` — full UI pass: Playwright journeys for every user-facing AC, axe accessibility
  scan, and visual/mobile checks where relevant (e.g. `/dp-test ui PROJ-12`).
- `perf` — adds a performance-testing pass (e.g. `/dp-test perf PROJ-12`).

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
> traceability). For each case pick the layer per `.devpilot/skills/test-strategy.md`:
> Angular unit, .NET unit, .NET integration, or Playwright UI journey. Write the matrix
> into `docs/qa/<slug>.md` BEFORE writing test code.

## Step 2 — Write the missing tests

Same agent, continuing:
> For each case with no covering test, write one in its layer:
> Angular specs per `.devpilot/skills/angular-testing.md`, .NET tests per
> `.devpilot/skills/dotnet-testing.md` (integration on real SQL Server).
> For every user-facing AC — and for **all** of them in `ui` mode — add a Playwright
> journey per `.devpilot/skills/ui-e2e-playwright.md` (happy path + one visible failure,
> data seeded via the API, axe scan on each new screen; visual + mobile projects in `ui`
> mode for design-critical screens). If the repo has no Playwright setup yet, scaffold
> `e2e/` as that skill describes first.
> If the input started with `perf` or an AC carries a performance requirement, load
> `.devpilot/skills/performance.md` (Part 2) and add/run the budgeted script under `perf/`.

## Step 3 — Run + verdict

> Run everything through the token-lean runner (`.devpilot/skills/token-lean-testing.md`):
> `bash scripts/run-tests.sh all` (or `e2e` in `ui` mode). Apply `.devpilot/skills/self-heal.md`
> on failures (3 attempts, re-running only the failing tests, test-code fixes only — an
> implementation bug is a 🔴 BLOCKER finding, never a weakened assertion). Commit tests with
> `test(<slug>): <what>`. Finish `docs/qa/<slug>.md` with the matrix, coverage added, suite
> summary table, trace paths for failures, and PASS / BLOCKED per AC.

## Report

```
🧪 /dp-test — <scope>
Cases designed:  <n> (P0: <n> · P1: <n> · P2 deferred: <n>)
Tests added:     unit <n> · integration <n> · UI journeys <n>
Suites:          dotnet ✅ <p>/<t> · angular ✅ <p>/<t> · e2e ✅ <p>/<t>  (or ❌ failing list)
Accessibility:   <axe: clean | n violations | not in scope>
Perf:            <budget table or "not in scope">
Blockers:        <real bugs found, or none>
QA report:       docs/qa/<slug>.md
```
