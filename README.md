# devpilot `v2.0.0`

> One command. AI team delivers the feature to develop. You review only for production.

Install devpilot on any project and run any feature, bug fix, or schema change with a single `/ceo` command. An AI team of BA, Team Lead, developers, and QA handles everything — requirements, planning, code, testing, and PR — then auto-merges into your development branch. You only review when promoting to production via `/binaa-prd`.

---

## How It Works

```
/ceo "add rental agreement PDF export"
         │
         ▼
  ── Phase 1: BA ──────────────────────────────────────────
  Project index freshness check (skip if < 2 hours old)
  Reads 3-8 relevant files — not the whole codebase
  Writes requirements + domain model (docs/requirements/)
  No clarifying questions — makes smart assumptions
         │
         ▼
  ── Phase 2: Team Lead ───────────────────────────────────
  Creates Jira ticket (Task or Epic + child Tasks)
  Creates feature branch from base_branch
  Writes implementation plan (docs/plans/<slug>.md)
  Logs start time, branch, engine to Jira
         │
         ▼
  ── Phase 3: Parallel Implementation ─────────────────────
  [Claude subagents — fully automatic, no manual step]
  Frontend agent   (if frontend work identified)
  Backend agent    (if backend work identified)
  DB agent         (if migrations needed)
  Integration agent (if messaging/services involved)
  Each agent: reads plan → builds → runs tests → commits
         │
         ▼
  ── Phase 4: QA ──────────────────────────────────────────
  Verifies every acceptance criterion
  Writes QA report (docs/qa/<slug>.md) — PASS or BLOCKED
  If BLOCKED: fixes issue, re-runs QA
         │
         ▼
  ── Phase 5: Team Lead ───────────────────────────────────
  Code review → writes review report (docs/reviews/)
  Opens PR → auto-merges into base_branch (develop)
  Jira ticket → Done
         │
         ▼
  ✅ DONE — Merged into develop + Jira Done + promote commands
```

**No stopping. No manual steps. No questions.** Auto-merges into develop — you review only for production via `/binaa-prd`.

---

## Quick Install

Run from the root of your project:

```bash
curl -s https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/binaa-ai-tech/devpilot
bash devpilot/install.sh
```

The installer will:
1. **Scan your system** — detect Claude Code, opencode, GitHub CLI, git, jq
2. **Scan your project stack** — detect Angular, React, .NET, Python, SQL migrations, etc.
3. **Recommend an agent team** — only enables agents relevant to your stack
4. **Choose implementation engine** — Claude (default, fully automatic) or opencode (manual terminal step)
5. **Configure Claude models** — BA, Team Lead, QA, and coding agents
6. **Choose command runner** — Claude Code CLI, opencode, or custom
7. **Download all files** — commands, agents, skills, scripts, templates
8. **Write `project.config.md`** — your per-project config, committed to git

Setup time: ~5 minutes.

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | All AI phases — BA, planning, code, QA, review |
| [GitHub CLI (`gh`)](https://cli.github.com) | Yes | PR creation, auto-merge, branch management |
| `git` | Yes | Branch management |
| `jq` | Yes | JSON building in Jira scripts |
| [opencode](https://opencode.ai) | Optional | Only if `engine: opencode` is set |

---

## After Install — Required Setup

### 1. Edit `.devpilot/config.sh` (gitignored — never commit)

```bash
# Jira
JIRA_BASE_URL="https://your-org.atlassian.net"
JIRA_EMAIL="you@example.com"
JIRA_API_TOKEN="your-token"   # generate at: id.atlassian.com/manage-profile/security/api-tokens
JIRA_PROJECT_KEY="APP"         # e.g. MSK, APP, PRJ

# Git / GitHub
GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"
TICKET_PREFIX="app"            # lowercase — used in branch names: feature/app-12-slug

# Environment URLs (fill in as each env is provisioned)
DEV_FRONTEND_URL="https://your-app-dev.example.com"
SIT_FRONTEND_URL="https://your-app-sit.example.com"
UAT_FRONTEND_URL="https://your-app-uat.example.com"
PRD_FRONTEND_URL="https://your-app.com"
```

### 2. Add GitHub Secrets (if using the deploy pipeline)

Go to: repo → Settings → Secrets and variables → Actions

Add secrets for each environment:
- `DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`

### 3. Create GitHub Environments

Go to: repo → Settings → Environments → New environment

Create: `dev`, `sit`, `uat`, `prd`

### 4. Start working

```
/ceo your first task description
```

---

## Commands

### Primary Entry Point

```
/ceo <description>
```

Full pipeline: BA → planning → implementation → QA → PR → auto-merge into develop.

```
/ceo add a dark mode toggle
/ceo fix the login redirect bug after password reset
/ceo production is down — users can't check out   ← triggers hotfix mode
```

### Command Taxonomy — 8 Commands for Every Scenario

| Command | Phases | Use when |
|---------|--------|----------|
| `/ceo <description>` | BA → Plan → Implement → QA → PR → Merge | Any feature, bug, or task |
| `/ceo-plan <description>` | BA → Jira "To Do" → save plan | Analyze first, implement later |
| `/ceo-run <KEY>` | Load plan → Implement → QA → PR → Merge | Execute a saved `/ceo-plan` |
| `/ceo-fix <bug>` | Team Lead scope → Implement → QA → PR → Merge | Fast bug fix, no BA needed |
| `/ceo-fe <description>` | Frontend only → QA → PR → Merge | Frontend-only change |
| `/ceo-be <description>` | Backend only → QA → PR → Merge | Backend-only change |
| `/ceo-db <description>` | DB/migration only → QA → PR → Merge | Schema or migration change |
| `/ceo-int <description>` | Integration only → QA → PR → Merge | Messaging, APIs, services |

**Decision guide:**

```
Is it a bug?
  → /ceo-fix "description"    (fast, no BA, scoped by Team Lead)

Is it a known scope (frontend/backend/db)?
  → /ceo-fe / /ceo-be / /ceo-db / /ceo-int

Do you want to analyze first, implement later?
  → /ceo-plan   (saves plan to docs/tasks/<KEY>-plan.md)
  → /ceo-run <KEY>   (runs the saved plan)

Everything else:
  → /ceo   (full pipeline, handles all cases)
```

All 8 commands run QA before creating the PR. No command skips QA.

### Branching Model

```
feature/KEY-slug
    │
    └─→ base_branch (develop)   ← auto-merge after QA (fully automatic)
              │
              └─→ main          ← /binaa-prd only, requires your review
```

You only review PRs when promoting to production. Everything else is automatic.

### Deploy Pipeline

After CI deploys to DEV, promote through environments:

| Command | Stage | When to run |
|---------|-------|-------------|
| `/binaa-sit <version>` | SIT | DEV testing passed |
| `/binaa-uat` | UAT | SIT QA passed |
| `/binaa-prd <version>` | PRD | UAT signed off — **opens PR, requires your review** |
| `/binaa-hotfix <n> <slug> <ver>` | Emergency | Production incident |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), bug fixes → bump PATCH (`1.0.0 → 1.0.1`).

### Individual Agents

| Command | What it does |
|---------|-------------|
| `/team-task <description>` | Full pipeline with detailed control |
| `/team-ba <description>` | BA phase only — write requirements |
| `/team-lead <context>` | Planning or review phase only |
| `/team-qa <context>` | QA phase only — verify ACs |
| `/team-frontend <context>` | Frontend agent standalone |
| `/team-dotnet <context>` | Backend/DB agent standalone |

### Change Models

```
/binaa-models backend github-copilot/gpt-5.3-codex   ← set one agent directly
/binaa-models                                          ← interactive wizard for all agents
/binaa-models list                                     ← show available models
```

Agent names: `ba` · `lead` · `qa` · `frontend` · `backend` · `db` · `integration`

### Full Reconfiguration

```
/binaa reconfig
```

Change implementation engine, agent enable/disable, base branch, runner CLI, or all model settings.

### Index the Project

```
/binaa-index
```

Regenerate `docs/project-index.md`. Run after major refactoring or before starting work on an unfamiliar area. The BA agent checks freshness automatically (skips if < 2 hours old) and regenerates only when needed.

---

## Implementation Engine

Set in `project.config.md → implementation.engine`:

| Engine | How it works | When to use |
|--------|-------------|-------------|
| `claude` (default) | Claude subagents write all code — fully automatic, no manual step | Default — everything works end-to-end |
| `opencode` | Claude does BA/planning/QA; you run opencode in terminal for coding | If you prefer a specific opencode model for coding |

Change anytime: `/binaa reconfig`

### Claude Engine (Default)

Spawn parallel subagents for all in-scope work:
- `team-frontend` for Angular/React
- `team-dotnet` for .NET backend/DB/integration

No manual steps. Claude handles the full pipeline.

### opencode Engine (Optional)

When `engine: opencode`, Claude writes implementation briefs then outputs:

```
⏸  IMPLEMENTATION HANDOFF — opencode
Branch: feature/MSK-42-pdf-export

  opencode --model "github-copilot/gpt-5.3-codex" < docs/implementation/pdf-export-frontend.md
  opencode --model "github-copilot/gpt-5.3-codex" < docs/implementation/pdf-export-backend.md

When ALL done → run: /ceo resume
```

Run each command in your terminal, then `/ceo resume` to continue with QA and PR.

---

## Running Commands from Any AI Tool

Every command can be run from opencode, Claude CLI, or any AI tool via shell scripts:

```bash
bash scripts/ceo.sh "add dark mode toggle"
bash scripts/ceo-fix.sh "login redirect broken after password reset"
bash scripts/ceo-fe.sh "fix mobile nav overflow"
bash scripts/ceo-be.sh "add rate limiting to auth endpoints"
bash scripts/ceo-db.sh "add index on rentals.created_at"
bash scripts/ceo-int.sh "connect to SendGrid for email notifications"
```

Configure the runner in `project.config.md`:

```yaml
runner:
  cli:   claude          # claude | opencode | custom
  model: ""              # e.g. github-copilot/gpt-5.3-codex (for opencode runner)
```

---

## Jira Integration

devpilot tracks every task end-to-end in Jira with human-readable comments:

| When | Jira action |
|------|-------------|
| Task starts | Ticket created → **In Progress** |
| Planning done | Comment: branch, plan path, scope, AC count |
| Implementation done | Comment: commit hashes, agent list |
| QA done | Comment: PASS/BLOCKED verdict, report path |
| PR merged | Comment: merged branch, PR URL, duration · Ticket → **Done** |

Task log also written to `docs/tasks/<KEY>.md` — permanent record of what was built.

**Ticket sizing rule:**
- ≤5 acceptance criteria AND 1-2 agents → single **Task** ticket
- >5 ACs OR 3+ agents → one **Epic** + one child **Task** per agent

**Supported Jira issue types:** `Task`, `Epic` only (available in all Jira Cloud projects).

---

## Project Configuration

`project.config.md` in your repo root controls everything. Generated at install, committed to git:

```yaml
project_name: "my-app"
project_type: fullstack
ticket_prefix: "APP"
base_branch: develop          # feature PRs auto-merge here; production PR is separate

stack:
  frontend: angular
  backend: dotnet
  database: sqlserver
  integration: none

agents:
  ba:          { enabled: true }
  team_lead:   { enabled: true }
  frontend:    { enabled: true }
  backend:     { enabled: true }
  db:          { enabled: true }
  integration: { enabled: false }
  qa:          { enabled: true }

implementation:
  engine: claude                                # claude (default) | opencode
  model_frontend:    "claude-sonnet-4-6"
  model_backend:     "claude-sonnet-4-6"
  model_db:          "claude-sonnet-4-6"
  model_integration: "claude-sonnet-4-6"

models:
  ba:         { tier1: claude-haiku-4-5-20251001 }
  team_lead:  { tier1: claude-sonnet-4-6 }
  qa:         { tier1: claude-haiku-4-5-20251001 }

runner:
  cli:   claude                                 # claude | opencode | custom
  model: ""                                     # e.g. github-copilot/gpt-5.3-codex
```

---

## Token Efficiency — Project Index

On every task, the BA agent checks for a fresh project index before doing anything:

```bash
if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
  echo "Project index is fresh — skipping regeneration"
else
  bash scripts/generate-project-index.sh
fi
```

`docs/project-index.md` is a map of every significant file with a one-line label. The BA reads this first, then reads only the 3-8 most relevant files for the task. This reduces token usage by ~80% compared to scanning the whole codebase.

---

## Artifacts Produced per Task

| Artifact | Location |
|----------|---------|
| Task log (permanent record) | `docs/tasks/<KEY>.md` |
| Project index | `docs/project-index.md` |
| Requirements | `docs/requirements/<slug>.md` |
| Domain model | `docs/domain-models/<slug>.md` |
| Implementation plan | `docs/plans/<slug>.md` |
| Implementation briefs (opencode engine) | `docs/implementation/<slug>-frontend.md`, etc. |
| QA report | `docs/qa/<slug>.md` |
| Architecture Decision Records | `docs/adrs/ADR-<N>-<slug>.md` |
| Code review report | `docs/reviews/<slug>.md` |
| Saved plans (ceo-plan) | `docs/tasks/<KEY>-plan.md` |

---

## File Structure

```
devpilot/
├── install.sh                         ← run this on any project to install devpilot
├── project.config.md                  ← per-project config (committed to git)
├── CLAUDE.md                          ← instructions for Claude Code
│
├── .devpilot/
│   ├── config.sh                      ← project secrets: Jira token, GitHub org, URLs (gitignored)
│   ├── rules.md                       ← coding standards for all stacks
│   ├── skills/
│   │   ├── get-shit-done.md           ← autonomous execution: no pauses, no questions
│   │   ├── spec-first.md              ← every code change must trace to an AC
│   │   ├── self-heal.md               ← build/test recovery + model limit fallback
│   │   ├── architecture-guard.md      ← layer rules and BLOCKER violations
│   │   ├── security-scan.md           ← security checklist (OWASP, SQL injection, etc.)
│   │   ├── performance-review.md      ← performance checklist
│   │   └── definition-of-done.md     ← DoD gate per agent role
│   ├── prompts/team/                  ← per-role detailed agent prompts
│   │   ├── ba-agent.md
│   │   ├── lead-plan.md
│   │   ├── lead-review.md
│   │   ├── frontend-agent.md
│   │   ├── dotnet-agent.md
│   │   └── qa-agent.md
│   └── templates/team/                ← document output templates
│       ├── requirements.md
│       ├── domain-model.md
│       ├── implementation-plan.md
│       ├── qa-report.md
│       ├── review-report.md
│       └── adr.md
│
├── .claude/
│   ├── agents/                        ← agent definitions with model frontmatter
│   │   ├── team-lead.md
│   │   ├── team-ba.md
│   │   ├── team-frontend.md
│   │   ├── team-dotnet.md
│   │   └── team-qa.md
│   └── commands/                      ← slash commands
│       ├── ceo.md                     ← /ceo — primary entry point (full pipeline)
│       ├── ceo-plan.md                ← /ceo-plan — analyze + save plan, no code yet
│       ├── ceo-run.md                 ← /ceo-run <KEY> — execute a saved plan
│       ├── ceo-fix.md                 ← /ceo-fix — fast bug fix (no BA)
│       ├── ceo-fe.md                  ← /ceo-fe — frontend agent only
│       ├── ceo-be.md                  ← /ceo-be — backend agent only
│       ├── ceo-db.md                  ← /ceo-db — DB/migration agent only
│       ├── ceo-int.md                 ← /ceo-int — integration agent only
│       ├── team-task.md               ← /team-task — full pipeline (detailed control)
│       ├── team-ba.md                 ← /team-ba — BA agent standalone
│       ├── team-lead.md               ← /team-lead — Team Lead standalone
│       ├── team-qa.md                 ← /team-qa — QA agent standalone
│       ├── binaa.md                   ← /binaa — command router + decision guide
│       ├── binaa-models.md            ← /binaa-models — set any agent's model
│       ├── binaa-index.md             ← /binaa-index — refresh project index
│       ├── binaa-reconfig.md          ← /binaa reconfig — full config wizard
│       ├── binaa-sit.md               ← /binaa-sit — promote to SIT
│       ├── binaa-uat.md               ← /binaa-uat — promote to UAT
│       ├── binaa-prd.md               ← /binaa-prd — promote to PRD (human review)
│       └── binaa-hotfix.md            ← /binaa-hotfix — emergency deploy
│
├── scripts/
│   ├── ceo.sh                         ← bash scripts/ceo.sh "task" (runs /ceo from any AI)
│   ├── ceo-fix.sh                     ← bash scripts/ceo-fix.sh "bug"
│   ├── ceo-fe.sh / ceo-be.sh          ← single-agent runners
│   ├── ceo-db.sh / ceo-int.sh
│   ├── ceo-plan.sh / ceo-run.sh
│   ├── run-command.sh                 ← generic AI runner (reads command .md, pipes to CLI)
│   ├── git-flow.sh                    ← feature/hotfix/release branch helpers
│   ├── generate-project-index.sh      ← build docs/project-index.md (token savings)
│   ├── create-jira-ticket.sh          ← create a Task ticket
│   ├── create-jira-epic.sh            ← create Epic + child Tasks for big features
│   ├── update-jira-status.sh          ← move ticket through workflow
│   ├── update-jira-description.sh     ← update ticket body
│   ├── add-jira-comment.sh            ← log agent activity to Jira
│   ├── deploy-dev.sh                  ← trigger DEV deploy
│   ├── deploy-sit.sh                  ← trigger SIT deploy
│   ├── deploy-uat.sh                  ← trigger UAT deploy
│   └── deploy-prd.sh                  ← trigger PRD deploy
│
└── docs/                              ← task artifacts (committed to git)
    ├── project-index.md               ← generated codebase map (auto-updated)
    ├── tasks/                         ← permanent task logs (<KEY>.md per task)
    ├── requirements/                  ← BA requirements docs
    ├── domain-models/                 ← domain model diagrams
    ├── plans/                         ← implementation plans
    ├── implementation/                ← opencode briefs per agent (opencode engine only)
    ├── qa/                            ← QA reports
    ├── adrs/                          ← Architecture Decision Records
    ├── reviews/                       ← code review reports
    └── fallback/                      ← model limit fallback prompts (gitignored)
```

---

## Hotfix Flow

When a production incident is detected, `/ceo "production is down — ..."` triggers expedited mode:

1. **Phase 1 (BA)** — skipped
2. **Phase 2 (Team Lead)** — branches from latest production tag, writes minimal plan
3. **Phase 3 (Code)** — affected layer only (frontend OR backend)
4. **Phase 4 (QA)** — smoke test of broken behavior + regression check
5. **Phase 5 (Review + PR)** — PR targets base branch; after merge, cherry-picks to develop

Or run directly: `/binaa-hotfix <ticket-num> <slug> <version>`

---

## Troubleshooting

### Auto-merge failed
If `gh pr merge` fails, the command prints `⚠️ Auto-merge failed` and leaves the PR open in "In Review". This usually means GitHub branch protection rules require CI checks to pass first. The PR will auto-merge once CI passes, or merge it manually.

### "Specify a valid issue type" error from Jira
Your Jira project may not have the `Story` type enabled. devpilot always uses `Task` and `Epic` — check that both exist in your project settings.

### opencode handoff not appearing
Check `project.config.md → implementation.engine`. If it reads `claude`, all implementation is handled by Claude subagents automatically. Set it to `opencode` if you want the manual terminal handoff.

### Feature branch created from wrong branch
Check `project.config.md → base_branch`. The `git-flow.sh feature-start` script reads this value. If missing, it falls back to `develop`.

### Project index is stale
Run: `bash scripts/generate-project-index.sh` — regenerates `docs/project-index.md`. Or run `/binaa-index` in Claude Code.

---

## License

MIT
