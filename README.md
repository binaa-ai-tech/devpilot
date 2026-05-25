# devpilot

> One person. Full AI dev team. One command delivers the merged PR.

Install devpilot on any project and run any feature, bug fix, or production emergency with a single `/ceo` command. An AI team of BA, Team Lead, and QA handles requirements, planning, testing, and review — while **opencode** with your preferred coding model writes the actual code.

---

## How It Works

```
/ceo "add rental agreement PDF export"
         │
         ▼
  ── Phase 1: BA (Claude Haiku) ──────────────────────────────
  Generates project index (docs/project-index.md)
  Reads 3-8 relevant files — not the whole codebase
  Writes requirements + domain model
  Creates Jira ticket (Task, or Epic + child Tasks for big features)
         │
         ▼
  ── Phase 2: Team Lead (Claude Sonnet) ──────────────────────
  Creates feature branch from base_branch
  Writes implementation plan (docs/plans/<slug>.md)
  Updates Jira ticket with full user story and ACs
         │
         ▼
  ── Phase 3: IMPLEMENTATION HANDOFF ─────────────────────────
  Claude writes one brief per coding agent:
    docs/implementation/<slug>-frontend.md
    docs/implementation/<slug>-backend.md

  You run each command in your terminal:
    opencode --model "github-copilot/gpt-4o" < docs/implementation/<slug>-frontend.md
    opencode --model "github-copilot/gpt-4o" < docs/implementation/<slug>-backend.md

  When done → /ceo resume
         │
         ▼
  ── Phase 4: QA (Claude Haiku) ──────────────────────────────
  Verifies every acceptance criterion
  Writes QA report (docs/qa/<slug>.md) — PASS or BLOCKED
         │
         ▼
  ── Phase 5: Team Lead (Claude Sonnet) ──────────────────────
  Code review → opens PR → merges into base branch
  Jira ticket closed ONLY after PR is confirmed merged
         │
         ▼
  ✅ DONE — PR merged + Jira closed + DEV link + promote commands
```

No clarifying questions. No stopping except the opencode handoff. The team reads your codebase, makes smart assumptions, and delivers.

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
4. **Ask for implementation engine** — opencode (recommended) or Claude subagents
5. **Configure Claude models** — BA, Team Lead, QA only (coding is handled by opencode)
6. **Download all files** — commands, agents, skills, scripts, templates
7. **Write `project.config.md`** — your per-project config, committed to git
8. **Sync agent models** — updates agent frontmatter to your chosen Claude models

Setup time: ~5 minutes.

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | BA, planning, QA, code review |
| [opencode](https://opencode.ai) | Yes (if `engine: opencode`) | Writes all implementation code |
| [GitHub CLI (`gh`)](https://cli.github.com) | Yes | PR creation, merge, branch management |
| `git` | Yes | Branch management |
| `jq` | Yes | JSON building in Jira scripts |

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

Add secrets for each environment you want to deploy to:
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

Examples:
```
/ceo add a dark mode toggle
/ceo fix the login redirect bug after password reset
/ceo production is down — users can't check out   ← triggers hotfix mode
/ceo resume                                        ← continue after opencode handoff
```

### Individual Agents (fine-grained control)

| Command | What it does |
|---------|-------------|
| `/team-task <description>` | Full 5-phase team workflow (same as `/ceo` for features/bugs) |
| `/team-ba <description>` | BA phase only — write requirements and domain model |
| `/team-lead <context>` | Planning or review phase only |
| `/team-qa <context>` | QA phase only — verify ACs and write report |

### Deploy Pipeline

After the PR merges and CI deploys to DEV, promote through environments:

| Command | Stage | When to run |
|---------|-------|-------------|
| `/binaa-sit <version>` | SIT | DEV testing passed |
| `/binaa-uat` | UAT | SIT QA passed |
| `/binaa-prd <version>` | PRD | UAT signed off |
| `/binaa-hotfix <n> <slug> <ver>` | Emergency | Production incident |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), bug fixes → bump PATCH (`1.0.0 → 1.0.1`).

### Index the Project

```
/binaa-index
```

Regenerate `docs/project-index.md` — run this after major refactoring, after adding new modules, or before starting work on an unfamiliar area of the codebase. The BA agent generates the index automatically on every task, but you can also refresh it manually anytime.

### Reconfigure Anytime

```
/binaa reconfig
```

Change implementation engine, opencode models per agent, or Claude models without reinstalling.

---

## Model Architecture

devpilot cleanly separates concerns between Claude and opencode:

| Phase | Engine | Default Model |
|-------|--------|--------------|
| BA (requirements, domain model) | Claude | `claude-haiku-4-5` |
| Planning + Jira + branch | Claude | `claude-sonnet-4-6` |
| **All coding (frontend, backend, DB)** | **opencode** | your configured model |
| QA (test verification) | Claude | `claude-haiku-4-5` |
| Review + PR + merge | Claude | `claude-sonnet-4-6` |

**Why this split?** Claude excels at understanding codebases, writing precise requirements, and verifying acceptance criteria. opencode with GitHub Copilot models generates large amounts of correct code quickly across multiple files. Each tool does what it does best.

### Configuring Coding Models (per agent)

Each developer role can use a different opencode model. Set in `project.config.md`:

```yaml
implementation:
  engine: opencode                                # opencode | claude
  model_frontend:    "github-copilot/gpt-4o"     # Angular / React / Vue
  model_backend:     "github-copilot/gpt-4o"     # .NET / Node / Python
  model_db:          "github-copilot/gpt-4o"     # DB migrations and SQL
  model_integration: "github-copilot/gpt-4o"     # Messaging / Services
```

Run `opencode model list` to see all available models. Common choices:
- `github-copilot/gpt-4o` — best all-round
- `github-copilot/gpt-3.5-codex` — fast and cheap
- `github-copilot/claude-3.5-sonnet` — strong reasoning + code quality

Run `/binaa reconfig` → choose "models" to change any agent's model anytime.

---

## Jira Integration

devpilot tracks every task end-to-end in Jira:

| When | What happens |
|------|-------------|
| Phase 1 (BA) | Ticket created (Task, or Epic + child Tasks for big features) |
| Phase 2 (Planning) | Ticket description updated with full user story + ACs; moved to **In Progress** |
| Phase 2 (Planning) | Jira comment: branch created, plan written |
| Phase 3 (Code) | Jira comment: implementation handoff or agent completion |
| Phase 4 (QA) | Jira comment: PASS or BLOCKED verdict |
| Phase 5 (PR merge) | PR merged → ticket moved to **Done** + merge confirmation |

**Ticket sizing rule:**
- ≤5 acceptance criteria AND 1-2 agents → single **Task** ticket
- \>5 ACs OR 3+ agents → one **Epic** + one child **Task** per agent (Frontend, Backend, DB, Integration)

**Critical invariant:** The Jira ticket is **never closed before the PR is merged.** Phase 5 verifies the PR state is `MERGED` before calling the close script.

### Supported Jira issue types
devpilot uses only: `Task`, `Epic`. No `Story` or `Bug` types (these are not available in all Jira Cloud projects).

---

## Project Configuration

`project.config.md` in your repo root controls everything. Generated at install, committed to git:

```yaml
project_name: "my-app"
project_type: fullstack
ticket_prefix: "APP"
base_branch: develop          # branch all PRs target

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
  engine: opencode             # opencode | claude
  model_frontend:    "github-copilot/gpt-4o"
  model_backend:     "github-copilot/gpt-4o"
  model_db:          "github-copilot/gpt-4o"
  model_integration: "github-copilot/gpt-4o"

models:
  ba:         { tier1: claude-haiku-4-5-20251001 }
  team_lead:  { tier1: claude-sonnet-4-6 }
  qa:         { tier1: claude-haiku-4-5-20251001 }
```

Edit directly or run `/binaa reconfig` for the interactive wizard.

---

## Token Efficiency — Project Index

On every task, the BA agent generates a **project index** before reading any code:

```bash
bash scripts/generate-project-index.sh
```

This produces `docs/project-index.md` — a map of every significant file in the project with a one-line label. The BA reads this index first, then reads only the 3-8 most relevant files for the task. This reduces token usage by ~80% compared to scanning the whole codebase.

The index is committed to git and updated automatically at the start of every BA phase.

---

## Artifacts Produced per Task

| Artifact | Location |
|----------|---------|
| Project index | `docs/project-index.md` |
| Requirements | `docs/requirements/<slug>.md` |
| Domain model | `docs/domain-models/<slug>.md` |
| Implementation plan | `docs/plans/<slug>.md` |
| Implementation briefs (for opencode) | `docs/implementation/<slug>-frontend.md`, `<slug>-backend.md`, etc. |
| QA report | `docs/qa/<slug>.md` |
| Architecture Decision Records | `docs/adrs/ADR-<N>-<slug>.md` |
| Code review report | `docs/reviews/<slug>.md` |

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
│       ├── ceo.md                     ← /ceo — primary entry point
│       ├── team-task.md               ← /team-task — full 5-phase workflow
│       ├── team-ba.md                 ← /team-ba — BA agent standalone
│       ├── team-lead.md               ← /team-lead — Team Lead standalone
│       ├── team-qa.md                 ← /team-qa — QA agent standalone
│       ├── binaa-index.md             ← /binaa-index — refresh project index
│       ├── binaa-sit.md               ← /binaa-sit — promote to SIT
│       ├── binaa-uat.md               ← /binaa-uat — promote to UAT
│       ├── binaa-prd.md               ← /binaa-prd — promote to PRD
│       ├── binaa-hotfix.md            ← /binaa-hotfix — emergency deploy
│       └── binaa-reconfig.md          ← /binaa reconfig — model config wizard
│
├── scripts/
│   ├── git-flow.sh                    ← feature/hotfix/release branch helpers
│   ├── new-feature.sh                 ← legacy feature branch helper
│   ├── generate-project-index.sh      ← build docs/project-index.md (token savings)
│   ├── create-jira-ticket.sh          ← create a Task ticket
│   ├── create-jira-epic.sh            ← create Epic + child Tasks for big features
│   ├── update-jira-status.sh          ← move ticket through workflow (In Progress → Done)
│   ├── update-jira-description.sh     ← update ticket body with user story
│   ├── add-jira-comment.sh            ← log agent activity to Jira
│   ├── deploy-dev.sh                  ← trigger DEV deploy
│   ├── deploy-sit.sh                  ← trigger SIT deploy
│   ├── deploy-uat.sh                  ← trigger UAT deploy
│   └── deploy-prd.sh                  ← trigger PRD deploy
│
└── docs/                              ← task artifacts (committed to git)
    ├── project-index.md               ← generated codebase map (auto-updated)
    ├── requirements/                  ← BA requirements docs per task
    ├── domain-models/                 ← domain model diagrams per task
    ├── plans/                         ← implementation plans per task
    ├── implementation/                ← opencode briefs per agent per task
    ├── qa/                            ← QA reports per task
    ├── adrs/                          ← Architecture Decision Records
    ├── reviews/                       ← code review reports per task
    └── fallback/                      ← model limit fallback prompts (gitignored)
```

---

## Hotfix Flow

When a production incident is detected, `/ceo "production is down — ..."` triggers expedited mode:

1. **Phase 1 (BA)** — skipped (no requirements doc needed for hotfixes)
2. **Phase 2 (Team Lead)** — branches from latest production tag, writes a minimal plan
3. **Phase 3 (Code)** — implementation brief for the affected layer only (frontend OR backend)
4. **Phase 4 (QA)** — smoke test of the specific broken behavior + regression around it
5. **Phase 5 (Review + PR)** — PR targets base branch; after merge, cherry-picks back to develop

---

## Troubleshooting

### "Specify a valid issue type" error from Jira
Your Jira project may not have the `Story` type enabled. devpilot always uses `Task` and `Epic` — check that both exist in your project settings.

### opencode handoff not appearing
Check `project.config.md → implementation.engine`. If it reads `claude` instead of `opencode`, run `/binaa reconfig` to switch.

### Feature branch created from wrong branch
Check `project.config.md → base_branch`. The `git-flow.sh feature-start` script reads this value. If missing, it falls back to `develop`.

### Jira ticket closed before PR merged
This should not happen — Phase 5 verifies `gh pr view <number> --json state` is `MERGED` before calling `update-jira-status.sh`. If it does happen, it means `gh pr merge` failed silently; check GitHub branch protection rules.

### Project index not found
Run: `bash scripts/generate-project-index.sh` — this creates `docs/project-index.md`. The BA agent does this automatically, but you can also run it manually anytime.

---

## License

MIT
