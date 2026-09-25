# DevPilot — AI delivery team (Angular + .NET, Claude Code)

Describe the requirement; the team plans → builds → tests → reviews → merges it.
The end-to-end SDLC contract (phases, gates, roles) lives in `.devpilot/process.md`.

---

## The 10 commands — one per team role

| Role | Command | Does |
|------|---------|------|
| Whole team | `/dp-deliver <requirement\|KEY> [--to sit]` | **End to end** — plan → sprint → build → QA → review → version bump → PR → merge into `develop` → items, Epic & sprint closed (→ SIT). Asks only if no tracker is connected (connect or skip) or on a gray-zone dedup. `/dp-deliver resume` continues after an interruption. |
| Product Owner / BA | `/dp-plan <requirement\|KEY>` | Dedup against the tracker + the top matches' child tasks, write Epic→Story with testable ACs. No code. |
| Scrum Master | `/dp-sprint` | Group READY Stories into sprints, recommend run order. |
| Developers | `/dp-build [sprint]` | Angular + .NET agents build a sprint on one branch → one PR → `develop`. |
| QA | `/dp-test [ui\|perf] [story\|PR\|diff]` | Cases from ACs → unit / integration / Playwright UI tests → run. |
| Tech Lead | `/dp-pr [PR]` | Apply review comments, drive CI green (bounded), merge per `auto-merge` gates. |
| DevOps | `/dp-release <sit\|uat\|prd\|rollback> [version]` | Promote DEV→SIT→UAT→PRD, or roll back. PRD is always human-approved. |
| On-call | `/dp-hotfix <ticket> <slug> <version>` | Emergency fix from the deployed tag + postmortem. |
| Everyone | `/dp-status [health\|board\|metrics]` | Health · board · throughput. |
| Admin | `/dp-setup [fix\|tracker\|pipelines\|models\|wizard\|index]` | Repair config, connect + self-test Jira / Azure DevOps / GitHub, set up CI/CD + approvals, switch Claude model profile, refresh index. |

---

## How it works

```
/dp-deliver "add CSV export"
  TRACKER → tracker.sh check · not configured → ask once: connect (API key) or continue locally
  PLAN    → classify · dedup vs tracker.sh search + child items (tracker.sh show) · Epic→Story first
  SPRINT  → feature: own sprint · bug: active sprint · P0/P1: refused → /dp-hotfix
  BUILD   → team-dotnet (API · EF Core · OpenAPI) ║ team-frontend (Angular · generated client)
  QA      → Vitest · xUnit + real SQL Server · Playwright journeys + axe
  REVIEW  → code-review · security · performance · test guard (strict)
  VERSION → version.sh bump from develop (feature → minor · bug → patch)
  MERGE   → one PR "[vX.Y.Z] …" → develop (auto-merge ladder; GitHub or Azure Repos)
  CLOSE   → close-delivery.sh: items Done · Epic Done · sprint closed · back on develop
            --to sit → release/<version> → SIT
```

**Dedup brain:** `/dp-plan` searches the live tracker (`tracker.sh search`, Done items included)
and `docs/backlog/index.md`, then opens only the top 1–3 candidates *with their child items*
(`tracker.sh show`) — an existing Story or Task under a matching Epic is reused, never duplicated.
Merges are reversible tracker links + one Story with combined ACs.

## Trackers & git hosts

| | Options | Interface |
|--|---------|-----------|
| Work tracker | Jira · Azure DevOps Boards · GitHub Issues · local (`docs/tasks/`) | `scripts/tracker.sh` (backends `jira.sh` · `azdo.sh` · `github.sh`) |
| Git host | GitHub (`gh` / GitHub MCP) · Azure Repos (`azdo.sh`, auto-complete) | `scripts/git-host.sh` → `open-pr.sh` |
| Version | `VERSION` · `Directory.Build.props` · `package.json` · `*.csproj` | `scripts/version.sh` |
| Delivery pipeline | `devpilot-cd`: build once → DEV → SIT → UAT → PRD (approvals on UAT/PRD) | `generate-ci.sh` · `deploy.sh` · `smoke.sh` · `setup-environments.sh` |

Never call a backend directly from a command — always `tracker.sh`. Secrets live in the gitignored
`.devpilot/config.sh`; same-named environment variables override it.

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
