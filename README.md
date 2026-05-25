# binaa-ai Dev Process

> Autonomous AI development team. Give a task, get a pull request.

This repository provides everything needed to run a fully autonomous AI development team on any software project. Once installed, a single `/ceo` command takes a feature description or bug report and delivers a pull request — with requirements, implementation plan, code, tests, and review — requiring only your initial answers to clarifying questions.

---

## Quick Install

Run from the root of any project:

```bash
curl -s https://raw.githubusercontent.com/binaa-ai-tech/dev-process/main/install.sh | bash
```

Then follow the printed setup checklist (config, secrets, GitHub environments).

---

## How It Works — CEO Perspective

You have two interactions for every task:

1. **Give the task** — one command, plain language
2. **Answer BA questions** — once, ~5 minutes

The team handles everything else.

```
You:          /ceo Add a feature that lets users filter listings by price range

BA Agent:     I have 6 clarifying questions — user story, data model, edge cases...

You:          [answer the questions]

Team Lead:    Creating Jira ticket KEY-42, branch feature/key-42-price-filter...
Frontend Dev: Implementing Angular filter component, price-range service...
.NET Dev:     Implementing /listings/search endpoint, adding DB index...
QA Agent:     Running 12 acceptance criteria, 4 edge cases, mutation testing...
Team Lead:    Code review complete. PR opened, auto-merging to develop...

CI:           lint ✅  test ✅  build ✅  deploy DEV ✅

Team:         ✅ DONE — Test on DEV: https://your-app-dev.onrender.com
              When ready: /binaa-sit 1.1.0
```

You then drive it to production:

| Your action | Command | What happens |
|-------------|---------|-------------|
| DEV looks good | `/binaa-sit 1.1.0` | Release branch cut → SIT auto-deploys |
| SIT passes | `/binaa-uat` | Approve UAT gate → UAT auto-deploys |
| UAT signed off | `/binaa-prd 1.1.0` | Merge to main → approve in GitHub Actions → PRD deploys |

---

## The Deploy Pipeline

```
feature/* ──┐
hotfix/*  ──┤── CI (lint + test + build) ──────────────────────── no deploy
            │
develop   ──┼── CI ──────────────────────────────────────────────── → DEV  (auto)
            │
release/* ──┼── CI ──────────────────────────────────────────────── → SIT  (auto)
            │                                               └──────► → UAT  (manual ✋)
            │
main      ──┘── CI ──────────────────────────────────────────────── → PRD  (manual ✋)
```

---

## Commands Reference

### CEO Entry Point

| Command | What it does |
|---------|-------------|
| `/ceo <description>` | Submit any task — auto-classifies as feature/bug/hotfix, runs the full team, delivers a PR with status report |

### Pipeline Commands

| Command | When to run |
|---------|-------------|
| `/binaa-sit <version>` | DEV tested → promote to SIT (e.g. `/binaa-sit 1.1.0`) |
| `/binaa-uat` | SIT passed → approve UAT gate |
| `/binaa-prd <version>` | UAT signed off → deploy to production |
| `/binaa-hotfix <n> <slug> <version>` | Production emergency — skip full flow |
| `/binaa-dev <type>: <description>` | Developer-assisted flow (uses opencode for implementation) |

### AI Team Commands (used internally by `/ceo` and `/team-task`)

| Command | Agent | Model | When |
|---------|-------|-------|------|
| `/team-task <description>` | Orchestrator | — | Full 5-phase team workflow |
| `/team-ba <description>` | Business Analyst | Haiku 4.5 | Requirements only |
| `/team-lead <context>` | Team Lead | Opus 4.7 | Planning or review only |
| `/team-frontend <context>` | Frontend Dev | Sonnet 4.6 | Angular/React work only |
| `/team-dotnet <context>` | .NET Dev | Sonnet 4.6 | API/DB work only |
| `/team-qa <context>` | QA Engineer | Haiku 4.5 | Testing only |

---

## Team Structure

```
┌─────────────────────────────────────────────────────┐
│            Team Lead  (Opus 4.7)                    │
│  Architecture · Planning · Code Review · PR         │
├──────────┬──────────────────────┬───────────────────┤
│  BA      │  Frontend Dev        │  .NET Dev         │
│ Haiku 4.5│  Sonnet 4.6          │  Sonnet 4.6       │
│          │                      │                   │
│ Require- │  Angular 21+         │  API endpoints    │
│ ments    │  Components          │  Services         │
│ Domain   │  Signals/State       │  Repositories     │
│ Modeling │  Tests               │  DB migrations    │
│          │                      │  Tests            │
├──────────┴──────────────────────┴───────────────────┤
│              QA Engineer  (Haiku 4.5)               │
│      Test plans · Acceptance criteria · Reports     │
└─────────────────────────────────────────────────────┘
```

---

## Output Documents Per Task

Every task produces a complete audit trail:

| Document | Path | Author |
|----------|------|--------|
| Requirements + User Stories | `docs/requirements/<slug>.md` | BA |
| Domain Model | `docs/domain-models/<slug>.md` | BA |
| Implementation Plan | `docs/plans/<slug>.md` | Team Lead |
| QA Report | `docs/qa/<slug>.md` | QA Engineer |
| Code Review + PR body | `docs/reviews/<slug>.md` | Team Lead |
| Architecture Decisions | `docs/adrs/ADR-<N>-<slug>.md` | Team Lead |

---

## Configuration

### 1. `.aidev/config.sh` (gitignored)

Created during install. Fill in your project values:

```bash
JIRA_BASE_URL="https://your-org.atlassian.net"
JIRA_EMAIL="you@example.com"
JIRA_API_TOKEN="your-api-token"
JIRA_PROJECT_KEY="KEY"       # e.g. MSK, APP, PRJ

GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"
TICKET_PREFIX="key"          # used in branch names: feature/key-42-slug

DEV_FRONTEND_URL="https://your-app-dev.onrender.com"
SIT_FRONTEND_URL="https://your-app-sit.onrender.com"
UAT_FRONTEND_URL="https://your-app-uat.azurewebsites.net"
PRD_FRONTEND_URL="https://your-app.com"
```

### 2. `.env` (gitignored, copy from `.env.example`)

```bash
JIRA_API_TOKEN=your-token
DEPLOY_HOOK_DEV_API=https://api.render.com/deploy/...
DEPLOY_HOOK_DEV_UI=https://api.cloudflare.com/...
DEPLOY_HOOK_SIT=https://api.render.com/deploy/...
DEPLOY_HOOK_UAT=https://your-hook.azurewebsites.net/...
DEPLOY_HOOK_PRD=https://your-hook.azurewebsites.net/...
```

### 3. GitHub Secrets (Settings → Secrets → Actions)

| Secret | Value |
|--------|-------|
| `DEPLOY_HOOK_DEV_API` | Render deploy hook for DEV API |
| `DEPLOY_HOOK_DEV_UI` | Cloudflare Pages hook for DEV UI |
| `DEPLOY_HOOK_SIT` | Render deploy hook for SIT |
| `DEPLOY_HOOK_UAT` | Azure / Render hook for UAT |
| `DEPLOY_HOOK_PRD` | Azure / Render hook for PRD |

### 4. GitHub Variables (Settings → Secrets → Variables)

| Variable | Example |
|----------|---------|
| `DEV_URL` | `https://your-app-dev.onrender.com` |
| `SIT_URL` | `https://your-app-sit.onrender.com` |
| `UAT_URL` | `https://your-app-uat.azurewebsites.net` |
| `PRD_URL` | `https://your-app.com` |

### 5. GitHub Environments (Settings → Environments)

| Environment | Required reviewers | When it deploys |
|-------------|-------------------|----------------|
| `dev` | None | Every push to `develop` |
| `sit` | None | Every push to `release/*` |
| `uat` | Add reviewers ✋ | After SIT (manual approval — needs GitHub Team plan) |
| `prd` | Add reviewers ✋ | Separate manual workflow |

---

## Rules & Standards

All agent-written code is governed by `.aidev/rules.md` — the single source of truth:

**Angular 21+**
- `takeUntilDestroyed()` for every subscription
- `ChangeDetectionStrategy.OnPush` on every component
- Signal-based state (`signal`, `computed`, `effect`) — no `BehaviorSubject`
- New control-flow syntax (`@if`, `@for`) — never `*ngIf` / `*ngFor`
- Standalone components only

**SQL Server / .NET**
- `SET NOCOUNT ON; SET XACT_ABORT ON;` on every stored procedure
- All SQL parameterized — zero string concatenation
- Named indexes: `IX_<Table>_<Cols>`, `UQ_<Table>_<Cols>`
- Idempotent migrations (`IF NOT EXISTS`)
- Clean architecture: Controller → Service → Repository → Database

**Universal**
- No `any` — explicit types or `unknown` + narrowing
- No magic numbers/strings — named constants
- No `console.log` in committed code
- Tests beside code, not in separate folders
- No secrets in code — all via environment config

---

## Power Skills

Every agent applies these automatically before committing:

| Skill | What it enforces |
|-------|------------------|
| `get-shit-done.md` | Autonomous execution — no unnecessary pauses |
| `security-scan.md` | SQL injection, XSS, auth bypass, hardcoded secrets |
| `performance-review.md` | N+1 queries, OnPush, lazy loading, async/await |
| `architecture-guard.md` | Clean architecture layers, smart/dumb component split |
| `self-heal.md` | 3-attempt error recovery before escalating to human |
| `definition-of-done.md` | Per-role DoD gate — nothing ships without passing |

---

## Scripts Reference

| Script | Usage |
|--------|-------|
| `scripts/git-flow.sh feature-start <n> <slug>` | Create feature branch from develop |
| `scripts/git-flow.sh release-start <version>` | Create release branch → triggers SIT CI |
| `scripts/git-flow.sh release-finish <version>` | Merge to main → tag → back to develop |
| `scripts/git-flow.sh hotfix-start <n> <slug>` | Create hotfix branch from main |
| `scripts/git-flow.sh hotfix-finish <version>` | Merge hotfix → tag → back to develop |
| `scripts/create-jira-ticket.sh "title" "desc" "Story"` | Create Jira ticket via API |
| `scripts/update-jira-status.sh KEY-42 "Done"` | Update Jira ticket status |
| `scripts/new-feature.sh KEY-42 "short description"` | Branch + scaffold impact map |
| `scripts/deploy-dev.sh` | Manually re-trigger DEV deploy |
| `scripts/deploy-sit.sh` | Manually re-trigger SIT deploy |
| `scripts/deploy-uat.sh` | Manually re-trigger UAT deploy |
| `scripts/deploy-prd.sh` | Emergency PRD re-trigger (has confirmation prompt) |

---

## Full File Structure

```
.aidev/
├── rules.md                      ← Code standards (read before every step)
├── config.sh                     ← Project config (gitignored)
├── README.md                     ← The 7-step single-agent workflow
├── prompts/
│   ├── 0-start-work.md           ← Full 7-stage automated flow
│   ├── 1-triage.md               ← Intake & triage
│   ├── 2-investigate.md          ← Investigation & impact map
│   ├── 4-implement-feature.md    ← Feature implementation
│   ├── 4-implement-bugfix.md     ← Bug fix (regression test first)
│   ├── 4-implement-refactor.md   ← Behavior-preserving refactor
│   ├── 4-copilot-implement.md    ← opencode / GitHub Copilot integration
│   ├── 5-self-review.md          ← Code review against rules.md
│   ├── 6-env-diff.md             ← Cross-environment failure diagnosis
│   ├── 6-generate-tests.md       ← Test coverage generation
│   ├── 7-pr-description.md       ← PR body generation
│   └── team/
│       ├── ba-agent.md           ← BA persona (requirements + domain model)
│       ├── lead-plan.md          ← Team Lead planning
│       ├── lead-review.md        ← Team Lead review (security/perf/arch/DoD)
│       ├── frontend-agent.md     ← Frontend implementation
│       ├── dotnet-agent.md       ← .NET implementation (clean arch)
│       └── qa-agent.md           ← QA (mutation mindset + acceptance criteria)
├── templates/
│   ├── impact-map.md             ← Pre-implementation analysis
│   ├── ticket.md                 ← Jira ticket structure
│   ├── pr-description.md         ← PR body template
│   ├── changelog-entry.md        ← Keep-a-Changelog format
│   └── team/
│       ├── requirements.md       ← BA output
│       ├── implementation-plan.md← Team Lead output
│       ├── qa-report.md          ← QA output
│       ├── review-report.md      ← Review + PR body
│       ├── adr.md                ← Architecture Decision Record
│       └── domain-model.md       ← Domain modeling
├── checklists/
│   ├── feature.md                ← 7-step DoD incl. full deploy pipeline
│   ├── bugfix.md                 ← Bug fix DoD
│   └── hotfix.md                 ← Hotfix DoD (expedited)
├── skills/
│   ├── get-shit-done.md          ← Autonomous execution rules
│   ├── security-scan.md          ← Security checklist
│   ├── performance-review.md     ← Performance checklist
│   ├── architecture-guard.md     ← Clean architecture enforcement
│   ├── self-heal.md              ← 3-attempt error recovery
│   └── definition-of-done.md    ← Per-role DoD gates
└── impact-maps/                  ← Generated per task (gitignored)

.claude/
├── agents/
│   ├── team-lead.md              ← Opus 4.7
│   ├── team-ba.md                ← Haiku 4.5
│   ├── team-frontend.md          ← Sonnet 4.6
│   ├── team-dotnet.md            ← Sonnet 4.6
│   └── team-qa.md                ← Haiku 4.5
└── commands/
    ├── ceo.md                    ← CEO entry point ← START HERE
    ├── team-task.md              ← Full 5-phase team orchestration
    ├── team-ba.md                ← Standalone BA
    ├── team-lead.md              ← Standalone Team Lead
    ├── team-frontend.md          ← Standalone Frontend Dev
    ├── team-dotnet.md            ← Standalone .NET Dev
    ├── team-qa.md                ← Standalone QA
    ├── binaa.md                  ← Pipeline router (all binaa-* commands)
    ├── binaa-dev.md              ← Start a task (developer-assisted)
    ├── binaa-sit.md              ← Promote to SIT
    ├── binaa-uat.md              ← Approve UAT gate
    ├── binaa-prd.md              ← Deploy to production
    └── binaa-hotfix.md           ← Emergency hotfix

scripts/
├── git-flow.sh                   ← Branch management (reads TICKET_PREFIX from config.sh)
├── new-feature.sh                ← Quick branch + impact map scaffold
├── create-jira-ticket.sh         ← Jira API: create ticket
├── update-jira-status.sh         ← Jira API: update status
├── deploy-dev.sh                 ← Manual DEV re-trigger
├── deploy-sit.sh                 ← Manual SIT re-trigger
├── deploy-uat.sh                 ← Manual UAT re-trigger
└── deploy-prd.sh                 ← Manual PRD re-trigger (with confirmation)

.github/
├── workflows/
│   ├── ci.yml                    ← Lint + test + build + deploy pipeline
│   └── deploy-prd.yml            ← Manual PRD deploy (workflow_dispatch only)
├── pull_request_template.md
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
├── BRANCH_NAMING.md
└── COMMIT_CONVENTION.md

docs/
├── team/README.md                ← AI team workflow guide
├── requirements/                 ← BA output per task
├── plans/                        ← Team Lead output per task
├── qa/                           ← QA reports per task
├── reviews/                      ← Code review reports per task
├── adrs/                         ← Architecture Decision Records
└── domain-models/                ← Domain models per task

CLAUDE.md                         ← Project memory (loaded at every session start)
install.sh                        ← One-command installer
.env.example                      ← Environment variable template
```

---

## FAQ

**Do I need Jira?**
No. Jira integration is optional — if credentials are missing the scripts skip ticket creation gracefully. The rest of the workflow runs without it.

**Does this work for any tech stack?**
The core workflow (CEO → team → PR → pipeline) works for any stack. The agents and `rules.md` are pre-configured for Angular + .NET + SQL Server. Update `.aidev/rules.md` and the agent prompts for your stack.

**What do the manual approval gates mean?**
GitHub Actions can require a human to click Approve before a deployment job runs. This needs the **GitHub Team plan**. On the free plan, remove required reviewers from the `uat` and `prd` environments — deployments will still be triggered but run automatically.

**How do version numbers work?**
Use semantic versioning:
- New feature → increment MINOR: `1.0.0 → 1.1.0`
- Bug fix → increment PATCH: `1.0.0 → 1.0.1`
- Breaking change → increment MAJOR: `1.0.0 → 2.0.0`

Check the current version: `git tag --sort=-version:refname | head -1`

**What if an agent gets stuck?**
Every agent applies `self-heal.md` — 3 recovery attempts with diagnosis before escalating. If still stuck, it reports exactly what blocked it and what decision is needed.

**Can I run individual agents standalone?**
Yes. Every phase has its own command:
- `/team-ba "describe the feature"` — just write requirements
- `/team-lead docs/requirements/my-feature.md` — just write the plan
- `/team-qa docs/plans/my-feature.md` — just run QA

**Which model runs which agent?**
- **Opus 4.7**: Team Lead (architectural decisions, review)
- **Sonnet 4.6**: Frontend Dev, .NET Dev (implementation)
- **Haiku 4.5**: BA, QA (rapid, cost-efficient)
