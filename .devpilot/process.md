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
| 1 | **Intake** | `/dp-plan` (or `/ceo`) | Item is classified, **deduped** against `docs/backlog/index.md`, and written as Epic→Story with a self-contained brief. **Hard-gated by `scripts/jira-guard.sh assert-key`** — no branch/code until a tracker key exists. |
| 2 | **Ready** | BA | `definition-of-ready.md` — clear, testable ACs; sized & sliced (`estimation-and-slicing.md`); no open questions. |
| 3 | **Sprint** | `/dp-sprint` | Only READY Stories enter; sprint has a goal and a recommended run order. |
| 4 | **Build** | `/dp-build` | One branch per sprint; layer agents stay in scope (`scope-guard`); every commit conventional, build never left red (`core-rules.md`). |
| 5 | **Verify** | QA agent, `/dp-test` | Test cases derived per AC (`test-case-design.md`); pyramid respected (`test-strategy.md`, `e2e-testing.md`); perf budgets proven when in scope (`performance-testing.md`); QA verdict **PASS** per Story. |
| 6 | **Merge** | `/dp-build` · `/dp-autofix` | The `auto-merge.md` gate ladder: build/lint/tests/audit/review/QA all green **on the PR head**. Auto-fix loop is bounded; humans merge when `merge_policy: pr-only`. |
| 7 | **Release** | `/dp-release` | Build once, promote the same artifact DEV→SIT→UAT→PRD (`ci-cd.md`, `release-discipline.md`); PRD always has a human approval; rollback path tested (`/dp-rollback`). |
| 8 | **Operate** | `/dp-hotfix` · `/dp-status` | Incidents get a blameless postmortem (`incident-postmortem.md`); action items return to Intake; SLOs watched (`reliability-slo.md`). |

A failed gate sends work **back one phase**, never forward with a TODO.

## Roles (the AI team)

| Role | Agent | Owns |
|------|-------|------|
| Business Analyst | `team-ba` | Intake, dedup, requirements, Definition of Ready |
| Team Lead | `team-lead` | Implementation plans, ADRs, review gate, merge decision |
| Developers | `team-frontend` / `team-backend` | Layer implementation, tests next to code |
| QA Engineer | `team-qa` | Test-case design, coverage, mutation mindset, the verdict |

## Cross-cutting standards (always on)

- **Spec-first** — every change traces to a verifiable AC (`spec-first.md`).
- **Security & data** — `threat-modeling` at design time, `security-scan` +
  `scripts/audit.sh` at diff time, `secrets-management`/`data-privacy` always.
- **Performance** — `performance-review` on code, `database-performance` on
  schema, `performance-testing` budgets on the running system.
- **Audit trail** — `docs/tasks/<KEY>.md` carries the blow-by-blow; the ticket
  gets exactly start + DONE (`core-rules.md` #11).
- **Token discipline** — read indexes first; load heavy skills only at the
  step that needs them (`.devpilot/skills/README.md`).

New to a repo? Run `/dp-status health`, then start at Intake with `/dp-plan` —
or say `/ceo "<what you want>"` and let the process run end to end.
