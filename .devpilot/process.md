# The DevPilot Standard Dev Process

One page that maps **idea → production** for any project devpilot is installed
into. A one-person team runs the same gates as a small software company; the
gates are enforced by skills and scripts, not by discipline alone. Commands
drive the phases; this page is the contract they all honor.

```
INTAKE → READY → SPRINT → BUILD → VERIFY → MERGE → RELEASE → OPERATE
```

## Phases & gates

| # | Phase | Driven by | Exit gate (must hold to advance) |
|---|-------|-----------|----------------------------------|
| 1 | **Intake** | `/dp-plan` (or `/dp-deliver`) | Item is classified, **deduped** against the live tracker (`tracker.sh search`) and the child items of the top matches (`tracker.sh show`), and written as Epic→Story (or one Bug) with a self-contained brief. **Hard-gated by `scripts/tracker.sh assert-key`** — no branch/code until a key exists. |
| 2 | **Ready** | BA · `/dp-spec` | `definition-of-ready` — clear, testable ACs; sized & sliced; no open questions; M/L Stories (per `spec_review`) passed the Elephant-Goldfish review — zero-context `egm-*` reviewers, no open 🔴 in `docs/specs/<slug>/review.md` (`spec-review`). |
| 3 | **Sprint** | `/dp-sprint` | Only READY Stories enter; sprint has a goal and a recommended run order. |
| 4 | **Build** | `/dp-build` | One branch per sprint; each layer agent edits only its layer (its prompt; `scope-guard.sh <layer>` reports cross-layer changes, `.devpilot/.scope-lock` enforces one layer on demand); every commit conventional, build never left red (`core-rules`). |
| 5 | **Verify** | QA agent, `/dp-test` | Test cases derived per AC and pyramid respected (`test-design`: Vitest · xUnit + real SQL Server · Playwright UI journeys per `ui-e2e-playwright`); suites run token-lean via `scripts/run-tests.sh`; perf budgets proven when in scope (`performance`); QA verdict **PASS** per Story. Then the change is **run**: `scripts/verify.sh` starts the app and drives the journeys the diff touches from `docs/feature-map.md` in a real browser; screenshots + `verify-report.md` land in `docs/tasks/<KEY>-evidence/` (`verify-change`). No passing report (or written "no runtime surface" reason) → no PR. |
| 6 | **Merge** | `/dp-build` · `/dp-pr` | Review read from the base branch (`rules-guard.sh show`), the diff-triggered reliability items answered with evidence (`reliability.sh match`), findings tagged 🔴 Important / 🟢 Nit / 🟣 Pre-existing; version bumped from `develop`'s version (feature → minor, bug → patch) and the PR titled `[vX.Y.Z]`; the `auto-merge` gate ladder all green **on the PR head**; squash-merge; then items **Done**, Epic Done when its children are, sprint closed when empty (`close-delivery.sh`). Fix loop bounded; humans merge when `merge_policy: pr-only`. |
| 7 | **Release** | `/dp-release` | `devpilot-cd` builds once and promotes the same artifact DEV→SIT→UAT→PRD with smoke tests (`deploy.sh`, `smoke.sh`); UAT and PRD wait for a human approval; tag + `main` only after PRD is verified; rollback = the pipeline on the previous tag (`release-ops`). |
| 8 | **Operate** | `/dp-hotfix` · `/dp-status` | Incidents get a blameless postmortem; action items return to Intake; SLOs watched (`release-ops`). |

A failed gate sends work **back one phase**, never forward with a TODO.

## Systems of record

| What | Options | Interface |
|------|---------|-----------|
| Work tracker (Epic · Story · Bug · sprint) | Jira · Azure DevOps Boards · GitHub Issues · local `docs/tasks/` | `scripts/tracker.sh` |
| Git host (PRs, CI, branch protection) | GitHub (Actions) · Azure Repos (Pipelines) | `scripts/git-host.sh` → `open-pr.sh`, `azdo.sh`, `gh` / GitHub MCP |
| Version | `VERSION` · `Directory.Build.props` · `package.json` · `*.csproj` | `scripts/version.sh` |

No tracker configured? The run asks once — connect one or continue locally — and never blocks.

## Roles (the AI team)

| Role | Agent | Owns |
|------|-------|------|
| Business Analyst | `team-ba` | Intake, dedup, requirements, Definition of Ready |
| Team Lead | `team-lead` | Implementation plans, ADRs, review gate, merge decision |
| Developers | `team-frontend` (Angular) / `team-dotnet` (.NET + SQL Server) / `team-python` (Python) | Layer implementation, tests next to code, OpenAPI contract kept in sync |
| QA Engineer | `team-qa` | Test-case design, coverage, mutation mindset, the verdict |

## Cross-cutting standards (always on)

- **Spec-first** — every change traces to a verifiable AC (`core-rules`, `definition-of-ready`).
- **Defect standard** — a bug is a single typed `Bug` issue (no Epic→Story), routed by
  severity: **P0/P1 → `/dp-hotfix`** (branch from `main`, postmortem); **P2 → active sprint**;
  **P3 → next sprint, batched**. The P0/P1 redirect is **hard-enforced** by
  `scripts/tracker.sh hotfix-gate` — `/dp-deliver` and `/dp-plan` refuse to plan/build one. Bug
  DoD is *reproduce-before-fix*: a regression test must fail on the unfixed code, then pass
  and stay (`definition-of-done` Bug DoD).
- **Security & data** — `security-scan` (threat model at design time; secrets, PII,
  dependencies at diff time) + `scripts/audit.sh`.
- **Contract** — the .NET API's OpenAPI spec is committed and the Angular client is generated
  from it; breaking changes are versioned (`api-contract`).
- **Performance** — `performance` on code and running-system budgets, `efcore-sqlserver`
  on schema and queries.
- **Audit trail** — `docs/tasks/<KEY>.md` carries the blow-by-blow; the ticket
  gets exactly start + DONE (`core-rules` #11).
- **Token discipline** — read indexes first; load heavy skills only at the
  step that needs them (`.claude/skills/README.md`).

## Review the reviewers

The review gate is itself checked. `bash scripts/review-metrics.sh [since]` lists merged PRs that
were later **reverted**, and `fix` commits that touched a recently merged PR's files within N days
(default 14) — with whether that PR's review report flagged the file. For each miss:

1. **Visible on a small diff?** If a reviewer reading only that diff could have caught it, it is a
   candidate reliability-checklist item: a trigger readable from a diff, a check question, and
   `Origin: #<PR>` (`.devpilot/reliability-checklist.md`, validated by `reliability.sh validate`).
2. **Recurs in ≥ 2 PRs** → add the item (a PR reviewed by a human — it edits the checks).
   **Seen once** → note it in the release's pruning review (`core-rules` → Pruning) and wait.
3. Not visible from the diff (data, environment, timing) → it belongs to tests or `verify-change`,
   not to the checklist.

The same pass prunes: items that never trigger or never catch anything are removed.

New to a repo? Run `/dp-status health`, then start at Intake with `/dp-plan` —
or say `/dp-deliver "<what you want>"` and let the process run end to end.
