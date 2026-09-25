# DevPilot — AI delivery team (Angular + .NET, Claude Code)

Describe the requirement; the team plans → builds → tests → reviews → merges it.
The end-to-end SDLC contract (phases, gates, roles) lives in `.devpilot/process.md`.

---

## The 10 commands — one per team role

| Role | Command | Does |
|------|---------|------|
| Whole team | `/dp-deliver <requirement> [--to sit]` | **End to end** — plan → sprint → build → QA → review → merge into `develop` (→ SIT). Stops only on a gray-zone dedup question. `/dp-deliver resume` continues after an interruption. |
| Product Owner / BA | `/dp-plan <requirement\|Jira key>` | Dedup against the backlog, write Epic→Story with testable ACs. No code. |
| Scrum Master | `/dp-sprint` | Group READY Stories into sprints, recommend run order. |
| Developers | `/dp-build [sprint]` | Angular + .NET agents build a sprint on one branch → one PR → `develop`. |
| QA | `/dp-test [ui\|perf] [story\|PR\|diff]` | Cases from ACs → unit / integration / Playwright UI tests → run. |
| Tech Lead | `/dp-pr [PR]` | Apply review comments, drive CI green (bounded), merge per `auto-merge` gates. |
| DevOps | `/dp-release <sit\|uat\|prd\|rollback> [version]` | Promote DEV→SIT→UAT→PRD, or roll back. PRD is always human-approved. |
| On-call | `/dp-hotfix <ticket> <slug> <version>` | Emergency fix from the deployed tag + postmortem. |
| Everyone | `/dp-status [health\|board\|metrics]` | Health · board · throughput. |
| Admin | `/dp-setup [fix\|models\|wizard\|index]` | Repair config, switch Claude model profile, refresh index. |

---

## How it works

```
/dp-deliver "add CSV export"
  PLAN    → classify · dedup vs docs/backlog/index.md · spec to git · Epic→Story to tracker
  SPRINT  → feature: own sprint · bug: active sprint · P0/P1: refused → /dp-hotfix
  BUILD   → team-dotnet (API · EF Core · OpenAPI) ║ team-frontend (Angular · generated client)
  QA      → Vitest · xUnit + real SQL Server · Playwright journeys + axe
  REVIEW  → code-review · security · performance · test guard (strict)
  MERGE   → one PR → develop (auto-merge ladder)  ·  --to sit → release branch → SIT
```

**Dedup brain:** `/dp-plan` matches each new item against `docs/backlog/index.md`, reading full
specs of only the top 1–3 candidates. Merges are reversible tracker links + one Story with
combined ACs.

---

## Token discipline

- **Two-tier index** — `docs/project-index.md` is a small bounded **map**; per-file detail lives in
  `docs/index/*.md` **shards** grepped by `scope.sh`, never loaded into context.
- **Scope once, reuse everywhere** — `bash scripts/scope.sh --save <slug> "<task>"` saves the
  ranked files to `docs/tasks/<slug>-scope.md`; later phases reuse it. Read only the top 3–8 files.
- **Hash-gated freshness** — the index regenerates only when repo content changed. Never broad-scan.
- **Read-once core** — `.devpilot/skills/core-rules.md`; load other skills only at the step that needs them.
- **Token-lean tests** — run suites via `bash scripts/run-tests.sh <angular|dotnet|e2e|all>`: the
  full log goes to `.devpilot/logs/`, only failures come back.

---

## Models (Claude only)

Each agent has a role model (`.claude/agents/*.md`); tasks are routed per complexity by
`scripts/resolve-model.sh`: **power** (Opus) for architectural / cross-cutting / high-risk work,
**standard** (Sonnet) for normal implementation, **lite** (Haiku) for simple, BA, and QA work.
Change with `/dp-setup models <auto|balanced|save>`. Reference: `.devpilot/config/models.md`.

---

## Stack, rules, skills

- **Frontend:** Angular 21+ · **Backend:** ASP.NET Core (C#) + EF Core + SQL Server ·
  **Contract:** OpenAPI → generated Angular client.
- **Tests:** Vitest (Angular) · xUnit + `WebApplicationFactory` + Testcontainers (.NET) · Playwright (UI/E2E).
- **Rules:** `.devpilot/rules.md` (router) + `.devpilot/rules/<angular|dotnet|sqlserver>.md`.
- **Skills:** `.devpilot/skills/` — index in `.devpilot/skills/README.md`.
- **Agents:** `.claude/agents/` — team-ba, team-lead, team-frontend, team-dotnet, team-qa
  (spawned by the commands; never called directly).

---

## Docs output per task

| Document | Path |
|----------|------|
| Backlog index | `docs/backlog/index.md` |
| Requirements + Domain Model | `docs/requirements/<slug>.md`, `docs/domain-models/<slug>.md` |
| Sprint plan | `docs/sprints/plan.md` |
| Implementation Plan + ADRs | `docs/plans/<slug>.md`, `docs/adrs/` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
| Step log + checkpoint | `docs/tasks/<KEY>.md`, `docs/tasks/<KEY>-checkpoint.json` |
