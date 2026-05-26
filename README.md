# devpilot `v2.1.0`

> One command. An AI team delivers the full feature — from BA breakdown to merged PR. Compatible with Claude Code, OpenCode, and Antigravity.

devpilot is a **portable, zero-config multi-agent orchestration layer** that installs into any project in minutes. It gives every AI coding engine — Claude, OpenCode, or Antigravity — the same structured team: Business Analyst, Team Lead, Frontend Dev, Backend Dev, DB Agent, and QA. You pick the engine; devpilot handles the rest.

---

## Install

Run from the root of your project:

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh
```

Or clone and run locally:

```bash
git clone https://github.com/binaa-ai-tech/devpilot
bash devpilot/install.sh
```

The installer:
1. Detects Claude Code, OpenCode, and Antigravity on your system
2. Scans your project stack (Angular, React, .NET, Python, SQL, etc.)
3. Enables only the agents your stack actually needs
4. Configures engine routing (`claude` | `opencode` | `antigravity`)
5. Writes per-engine model config (`coding_models` in `project.config.md`)
6. Copies `.claude/`, `.opencode/`, `.devpilot/`, `scripts/`, `AGENTS.md`, `CLAUDE.md`

Setup time: ~5 minutes.

---

## System Overview

devpilot sits between you and your AI CLI. You describe the task; devpilot orchestrates a structured team to complete it — requirements, planning, implementation, QA, and PR — with full state persistence so any engine can resume where another left off.

```
You → /ceo "add rental agreement PDF export"
           │
           ▼
   ┌───────────────────────────────────────────────────┐
   │  devpilot orchestration layer                     │
   │                                                   │
   │  Engine routing  →  claude | opencode | antigravity│
   │  State engine    →  docs/tasks/<KEY>-checkpoint.json│
   │  Credential CLI  →  scripts/devpilot-config.sh    │
   └───────────────────────────────────────────────────┘
           │
           ▼
   BA → Team Lead → [Frontend | Backend | DB | Integration] → QA → PR
```

**All three AI engines run the same workflow.** Claude uses subagents. OpenCode and Antigravity run the same steps as a single-agent loop — no subagents, no workarounds.

---

## The 3 Multi-Agent Tracks

### Track 1 — Full CEO Process (`/ceo`)

End-to-end autonomous engineering. The BA reads the codebase, writes requirements, the Team Lead creates the Jira ticket and branch, implementation agents build the code, QA verifies every acceptance criterion, and the Team Lead opens and merges the PR.

```
/ceo "description"
     │
     ▼
[BA] Reads project-index → writes requirements + domain model
     │
     ▼
[Team Lead] Creates Jira ticket → feature branch → implementation plan
     │
     ▼
[Parallel — only agents enabled for your stack]
  ├── Frontend Dev   (if frontend work in plan)
  ├── Backend Dev    (if backend work in plan)
  ├── DB Agent       (if migrations in plan)
  └── Integration    (if messaging/services in plan)
     │
     ▼
[QA] Verifies all ACs → writes QA report → fixes blockers
     │
     ▼
[Team Lead] Code review → PR → auto-merge into base_branch
     │
     ▼
✅  Merged + Jira Done + promote commands printed
```

**No stopping. No questions. No manual steps.** Auto-merges into `develop`; you review only for production.

Subcommands:

| Command | What it runs |
|---------|-------------|
| `/ceo-plan <description>` | BA + planning only — saves Jira ticket, branch, and plan; no code written |
| `/ceo-run <KEY>` | Loads saved plan → implementation → QA → PR — resumes a `/ceo-plan` |
| `/ceo-fe <description>` | Frontend implementation only |
| `/ceo-be <description>` | Backend implementation only |
| `/ceo-db <description>` | DB/migration only |
| `/ceo-int <description>` | Integration/services only |

---

### Track 2 — CEO Issue Loop (`/ceo-issue`)

Team Lead-driven rapid bug triage that **bypasses the BA layer**. Use when you have a production or regression bug that needs a fast, targeted fix.

```
/ceo-issue "sessions table not found on first boot"
     │
     ▼
[Team Lead] Root cause hypothesis + layers affected + severity (P0/P1/P2)
     │
     ▼
[Team Lead] Creates Jira Epic + per-layer sub-tasks (only affected layers)
            Creates branch → writes checkpoint
     │
     ▼
[Layer-locked agents — only layers with confirmed root cause]
  ├── Backend agent  SCOPE LOCK: backend/ only
  ├── DB agent       SCOPE LOCK: migrations/ only
  └── Integration    SCOPE LOCK: services/ only
     │
     ▼
[QA] Severity-proportional — P0 gets regression suite, P2 gets targeted check
     │
     ▼
[Team Lead] PR → auto-merge → close Epic → update checkpoint
```

Layer-scope locking prevents agents from touching code outside their domain, eliminating cross-layer regressions in hotfix scenarios.

---

### Track 3 — CEO Sub-Domain Scoped Fixer (`/ceo-subdomain`)

Restricts agent permissions to a single technical vertical. Use when you need a change strictly confined to one layer — security hardening, performance optimization in a single service, or a schema-only migration.

```
/ceo-subdomain frontend "migrate all ngIf to new @if control flow"
/ceo-subdomain backend  "add rate limiting to all API endpoints"
/ceo-subdomain db       "add missing indexes on FK columns"
/ceo-subdomain security "audit and fix all SQL injection risks in repository layer"
```

The agent receives an explicit `SCOPE LOCK` constraint. Any file outside the declared domain is off-limits. Produces the same QA report and PR as Track 1.

---

## Dynamic Configuration Schema

`project.config.md` is the single source of truth for all routing decisions. Commit it to git.

```yaml
# project.config.md

project_name: my-app
base_branch: develop

stack:
  frontend: angular    # angular | react | vue | none
  backend:  dotnet     # dotnet | node | python | go | none
  database: sqlserver  # sqlserver | postgres | mysql | none
  mobile:   none

engines:
  orchestrator: claude          # always claude — Claude Code drives orchestration
  coding: claude                # claude | opencode | antigravity
  runner: claude                # claude | opencode | antigravity | custom
  fallback: opencode            # engine to use when primary hits a limit

coding_models:
  opencode:
    frontend:    "github-copilot/gpt-4o"
    backend:     "github-copilot/gpt-4o"
    db:          "github-copilot/gpt-4o"
    integration: "github-copilot/gpt-4o"
  antigravity:
    frontend:    ""
    backend:     ""
    db:          ""
    integration: ""

agents:
  ba:          { enabled: true,  model: "claude-sonnet-4-6" }
  lead:        { enabled: true,  model: "claude-sonnet-4-6" }
  qa:          { enabled: true,  model: "claude-sonnet-4-6" }
  frontend:    { enabled: true,  model: "claude-haiku-4-5" }
  backend:     { enabled: true,  model: "claude-haiku-4-5" }
  db:          { enabled: true,  model: "claude-haiku-4-5" }
  integration: { enabled: false, model: "claude-haiku-4-5" }
```

**Engine routing examples:**

```yaml
# Fully automatic — Claude writes all code
engines:
  coding: claude
  runner: claude

# OpenCode writes code; Claude orchestrates BA/QA/review
engines:
  coding: opencode
  runner: opencode
  fallback: antigravity

# Antigravity for coding; fall back to opencode on limit
engines:
  coding: antigravity
  runner: antigravity
  fallback: opencode
```

Change models for a single agent without touching the file:

```bash
/binaa-models backend github-copilot/gpt-4o
/binaa-models                                  # interactive wizard
```

---

## Credential & Token Rotation CLI

`scripts/devpilot-config.sh` manages all credentials in `.devpilot/config.sh` with live Jira validation. Never edit the file manually.

```bash
# Show all current config (tokens masked)
bash scripts/devpilot-config.sh show

# Read a single value
bash scripts/devpilot-config.sh get jira_api_token

# Update a value (validates Jira connectivity immediately after)
bash scripts/devpilot-config.sh set jira_api_token=<new-token>
bash scripts/devpilot-config.sh set jira_base_url=https://your-org.atlassian.net
bash scripts/devpilot-config.sh set github_org=your-org

# Run full connectivity validation
bash scripts/devpilot-config.sh validate
```

`validate` makes a live call to the Jira API and reports:
- `200 OK` — credentials are valid
- `401 Unauthorized` — bad token, rotate immediately
- `403 Forbidden` — token valid but insufficient project permissions
- `000 (no response)` — network or URL issue

---

## Cross-Tool State Persistence

Every task that touches the checkpoint engine saves its state to `docs/tasks/<KEY>-checkpoint.json`. If the primary engine hits a rate limit or you want to switch tools mid-task, run:

```bash
bash scripts/checkpoint.sh show KEY-123       # inspect current state
bash scripts/checkpoint.sh latest             # find most recent in-progress task
```

The fallback engine reads the checkpoint and resumes from the exact phase that was interrupted — no re-running BA or re-generating plans.

```json
{
  "key": "KEY-123",
  "branch": "feature/key-123-add-user-auth",
  "phase_completed": "implementation",
  "next_phase": "qa",
  "agents_completed": ["ba", "lead", "frontend", "backend"],
  "agents_remaining": ["qa"],
  "coding_engine": "claude",
  "pause_reason": "claude_limit"
}
```

---

## Deploy Pipeline

After CI deploys to DEV, promote through environments:

| Command | Stage | Trigger |
|---------|-------|---------|
| `/binaa-sit <version>` | SIT | DEV testing passed |
| `/binaa-uat` | UAT | SIT QA passed |
| `/binaa-prd <version>` | PRD | UAT signed off — **opens PR, requires your review** |
| `/binaa-hotfix <n> <slug> <ver>` | Emergency | Production incident |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), fixes → bump PATCH (`1.0.0 → 1.0.1`).

---

## After Install — Required Setup

### 1. Set credentials

```bash
bash scripts/devpilot-config.sh set jira_base_url=https://your-org.atlassian.net
bash scripts/devpilot-config.sh set jira_email=you@example.com
bash scripts/devpilot-config.sh set jira_api_token=<token-from-id.atlassian.com>
bash scripts/devpilot-config.sh set jira_project_key=APP
bash scripts/devpilot-config.sh set github_org=your-org
bash scripts/devpilot-config.sh set github_repo=your-repo
bash scripts/devpilot-config.sh validate
```

### 2. Add GitHub Secrets (deploy pipeline only)

Repo → Settings → Secrets → Actions:
- `DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`

### 3. Create GitHub Environments

Repo → Settings → Environments: `dev`, `sit`, `uat`, `prd`

### 4. Start working

```
/ceo your first task
```

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | Orchestration — BA, planning, QA, review |
| [GitHub CLI (`gh`)](https://cli.github.com) | Yes | PR creation, auto-merge, branch management |
| `git` | Yes | Branch management |
| `jq` or `python3` | Yes | JSON operations in checkpoint/config scripts |
| [OpenCode](https://opencode.ai) | Optional | If `engines.coding: opencode` |
| Antigravity | Optional | If `engines.coding: antigravity` |

---

## Project Structure

```
.claude/
  commands/          # /ceo, /ceo-issue, /ceo-subdomain, /ceo-fix, /ceo-fe, /ceo-be, /ceo-db, /ceo-int, /ceo-plan, /ceo-run
                     # /binaa-sit, /binaa-uat, /binaa-prd, /binaa-hotfix, /binaa-models, /binaa-index, /binaa-reconfig
  agents/            # team-ba, team-lead, team-frontend, team-dotnet, team-qa
.opencode/
  config.json        # OpenCode project config — points to AGENTS.md and .devpilot/rules.md
.devpilot/
  rules.md           # Universal + stack-conditional code rules
  skills/            # compact-context, self-heal, definition-of-done, security-scan, performance-review
  config/            # models.md — per-agent model reference
  templates/         # requirements, plan, qa-report, review-report, adr
scripts/
  run-command.sh     # Generic AI command runner — routes to claude | opencode | antigravity
  checkpoint.sh      # Task state persistence engine
  devpilot-config.sh # Credential management + Jira validation CLI
  git-flow.sh        # Feature/release/hotfix branch helper
  generate-project-index.sh  # Dynamic codebase index generator
  create-jira-ticket.sh      # Jira Task/Epic creation
  update-jira-status.sh      # Jira workflow transitions
  deploy-*.sh                # Per-environment deploy scripts
docs/
  requirements/      # BA output — one file per task
  plans/             # Implementation plans
  qa/                # QA reports
  reviews/           # Code review reports
  tasks/             # Checkpoint JSON files
  domain-models/     # Domain model diagrams
  adrs/              # Architecture decision records
AGENTS.md            # OpenCode/Antigravity project context (equivalent of CLAUDE.md)
CLAUDE.md            # Claude Code project context
project.config.md    # Per-project config — engine routing, models, stack, agents
install.sh           # One-command installer
```

---

## License

MIT — use freely in any project, commercial or otherwise.
