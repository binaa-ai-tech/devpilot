# devpilot `v2.3.0`

> One command. An AI team delivers the full feature — from BA breakdown to merged PR. Compatible with Claude Code, OpenCode, and Antigravity.

devpilot is a **portable, zero-config multi-agent orchestration layer** that installs into any project in minutes. It gives every AI coding engine — Claude, OpenCode, or Antigravity — the same structured team: Business Analyst, Team Lead, Frontend Dev, Backend Dev (stack-aware), DB Agent, and QA. You pick the engine; devpilot handles the rest.

**Built for a one-person team to operate like a small company:**
- **Engine modes per task** — `/ceo --claude`, `--opencode`, or `--max` (race both engines and merge the winner).
- **Zero external setup** — issue tracking defaults to `local` (a file log); GitHub Issues or Jira are opt-in. `gh` is optional too.
- **Token-lean** — agents retrieve only the files relevant to a task (`scope.sh` + a project index) and `/ceo` routes small work to a fast path instead of the full 5-phase flow.
- **Any stack** — a stack-aware backend agent + per-stack rule snippets (`.devpilot/rules/<stack>.md`) for .NET, Node, Python, Go, Java, Angular, React/Vue, SQL Server, Postgres/MySQL.
- **A professional operating manual** — process skills for code review, testing, debugging, slicing, tech-debt, observability, release discipline, and status reporting (`.devpilot/skills/`).

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
2. Scans your project stack (Angular, React, .NET, Node, Python, Go, Java, SQL, etc.)
3. Enables only the agents your stack actually needs
4. Configures engine routing (`claude` | `opencode` | `antigravity`), issue tracker (`local` | `github` | `jira`), and merge policy (`auto` | `pr-only`)
5. Writes per-engine model config (`coding_models` in `project.config.md`) and copies only the rule snippets for your stack
6. Copies `.claude/` (commands, agents, SessionStart hook), `.opencode/`, `.devpilot/`, `scripts/`, `AGENTS.md`, `CLAUDE.md`

Setup time: ~5 minutes.

**Updating an existing install** — refresh the managed files without touching your config:

```bash
bash install.sh --update    # refreshes .claude/, .devpilot/, scripts/
                            # never overwrites project.config.md or .devpilot/config.sh
```

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

**No stopping. No questions. No manual steps.** Auto-merges into `develop` (set `merge_policy: pr-only` to require a human merge); you review only for production.

**Engine modes** — pick how a task runs with a leading flag (no flag → `engines.coding`):

| Flag | Behaviour |
|------|-----------|
| `/ceo --claude <task>` | All phases + coding on Claude subagents |
| `/ceo --opencode <task>` | Claude orchestrates; opencode writes all code |
| `/ceo --max <task>` | Race **both** engines on isolated branches, judge, merge the winner |

**Size routing** — `/ceo` sizes the task first: trivial → fast fix path, single-layer → layer-locked, multi-layer/large → the full team flow below. Small work never pays for the full 5-phase pipeline.

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

The agent receives an explicit `SCOPE LOCK` constraint. Any file outside the declared domain is off-limits — enforced by `scripts/scope-guard.sh`. Produces the same QA report and PR as Track 1.

---

## Command Reference

**Build / fix**

| Command | Purpose |
|---------|---------|
| `/ceo [--claude \| --opencode \| --max] <task>` | Full autonomous flow; engine mode optional |
| `/ceo-plan <task>` · `/ceo-run <KEY>` | Plan only / execute a saved plan |
| `/ceo-fix <bug>` | Fast bug fix (no BA, no formal docs) |
| `/ceo-issue <bug>` | Issue triage → per-layer locked fix |
| `/ceo-subdomain <scope> <task>` | Layer-locked change (`frontend`/`backend`/`db`/`security`) |
| `/ceo-fe` · `/ceo-be` · `/ceo-db` · `/ceo-int` | Single-agent implementation |
| `/ceo-review-fix <PR>` | Read PR review comments → apply fixes → push |

**Individual agents**

| Command | Runs |
|---------|------|
| `/team-task <task>` | The full team flow (what `/ceo` orchestrates) |
| `/team-ba` · `/team-lead` · `/team-frontend` · `/team-backend` · `/team-qa` | One role directly |

**Config & deploy**

| Command | Purpose |
|---------|---------|
| `/binaa reconfig` · `/binaa-models` | Re-run the wizard / set per-agent models |
| `/binaa-index` | Refresh the project index |
| `/binaa-doctor` · `/binaa-status` · `/binaa-metrics` | Pre-flight health check · task dashboard · throughput metrics |
| `/binaa-sit` · `/binaa-uat` · `/binaa-prd` · `/binaa-hotfix` · `/binaa-rollback` | Promote DEV→SIT→UAT→PRD · hotfix · roll back a release |
| `bash install.sh --update` | Refresh devpilot itself (config preserved) |

---

## Issue Tracking — zero setup by default

devpilot logs each task's lifecycle (start → plan → implementation → QA → merge). Pick a backend in `project.config.md`; all flows go through `scripts/track.sh`, so you can switch anytime without touching a command.

| `tracker.type` | Behaviour | Setup |
|----------------|-----------|-------|
| `local` *(default)* | Logs to `docs/tasks/<KEY>.md` — no external service | none |
| `github` | Opens & comments on GitHub Issues via `gh` | `gh auth login` (falls back to `local` if absent) |
| `jira` | Full Jira Cloud integration | credentials in `.devpilot/config.sh` |

---

## Token Efficiency

devpilot works on **only the code relevant to the task** — never the whole repo:

- **Project index** (`scripts/generate-project-index.sh`) — a fast-scan map of the codebase, auto-refreshed (and on session start).
- **Scoped retrieval** (`scripts/scope.sh`) — ranks the few files relevant to a task; agents read those, not the tree.
- **Size routing** — `/ceo` sends trivial work to a fast path and single-layer work to a locked track, skipping the full 5-phase docs for small changes.
- **Compact handoffs** — agents get a compact brief (ACs + files to touch), not raw document dumps.
- **On-demand skills** — agents always load `core-rules.md` and pull heavier skills only when needed.

---

## Quality Gates

Nothing merges until it passes:

- **Definition of Done** — per-role checklist (`.devpilot/skills/definition-of-done.md`).
- **Code-review gate** — Team Lead reviews the diff with severity tags (🔴/🟡/🟢); an open 🔴 blocks the PR.
- **Security scan + dependency audit** — checklist over the diff plus `scripts/audit.sh` (npm/pip/dotnet/go); new high/critical CVEs block the PR.
- **QA verdict** — every acceptance criterion has a test; PASS or BLOCKED.
- **Scope guard** — `scripts/scope-guard.sh` (post-check) **and** a real-time `PreToolUse` hook (`scripts/scope-hook.sh`) that blocks out-of-layer writes during `/ceo-subdomain`.
- **Conventional commits** — a `commit-msg` git hook enforces the format locally.
- **Merge policy** — `auto` (squash-merge) or `pr-only` (a human merges); production always needs human sign-off.

Run `/binaa-doctor` before starting to catch setup problems early.

---

## Stack Support

A single **stack-aware backend agent** adapts to your language; rules are split into per-stack snippets so agents read only what applies (`.devpilot/rules/<stack>.md`, routed by `.devpilot/rules.md`).

| Layer | Supported |
|-------|-----------|
| Frontend | Angular · React · Vue · Next.js |
| Backend | .NET · Node/TypeScript · Python · Go · Java |
| Database | SQL Server · PostgreSQL · MySQL |

---

## Skills — the Team's Operating Manual

`.devpilot/skills/` is what makes the agents behave like a disciplined team. Index: `.devpilot/skills/README.md`.

| Phase | Skills |
|-------|--------|
| Always | `core-rules` · `get-shit-done` · `compact-context` |
| Planning | `spec-first` · `estimation-and-slicing` |
| Build | `architecture-guard` · `test-strategy` · `observability` · `performance-review` · `self-heal` |
| Quality & ship | `code-review` · `security-scan` · `definition-of-done` · `release-discipline` |
| Cross-cutting | `debug-method` · `tech-debt` · `status-reporting` |

---

## Dynamic Configuration Schema

`project.config.md` is the single source of truth for all routing decisions. Commit it to git.

```yaml
# project.config.md

project_name: my-app
base_branch: develop   # PRs target & DEV deploys from this; defaults to develop when it exists

tracker:
  type: local          # local | github | jira  — local = zero setup, logs to docs/tasks/

merge_policy: auto      # auto = devpilot squash-merges the PR | pr-only = a human merges
language: en            # human language for BA/QA/review docs (code stays English)

stack:
  frontend: angular    # angular | react | vue | nextjs | none
  backend:  dotnet     # dotnet | node | python | go | java | none
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
| `git` | Yes | Branch management |
| [GitHub CLI (`gh`)](https://cli.github.com) | Optional | PR auto-merge; without it `open-pr.sh` prints a compare URL / uses GitHub MCP |
| `jq` or `python3` | Optional | JSON operations in checkpoint/config scripts |
| [OpenCode](https://opencode.ai) | Optional | If `engines.coding: opencode` or `/ceo --opencode` / `--max` |
| Antigravity | Optional | If `engines.coding: antigravity` |

---

## Project Structure

```
.claude/
  commands/          # /ceo, /ceo-issue, /ceo-subdomain, /ceo-fix, /ceo-fe, /ceo-be, /ceo-db, /ceo-int, /ceo-plan, /ceo-run
                     # /binaa-sit, /binaa-uat, /binaa-prd, /binaa-hotfix, /binaa-models, /binaa-index, /binaa-reconfig
  agents/            # team-ba, team-lead, team-frontend, team-backend (stack-aware), team-dotnet (alias), team-qa
  settings.json      # SessionStart hook → scripts/session-start.sh
.opencode/
  config.json        # OpenCode project config — points to AGENTS.md and .devpilot/rules.md
.devpilot/
  rules.md           # Router → reads core-rules + the snippet for your stack
  rules/             # angular, react-vue, dotnet, node, python, go, java, sqlserver, postgres-mysql
  skills/            # README.md index + core-rules, get-shit-done, compact-context, self-heal,
                     # code-review, test-strategy, debug-method, estimation-and-slicing, tech-debt,
                     # observability, release-discipline, status-reporting, security-scan, …
  config/            # models.md — per-agent model reference
  templates/         # requirements, plan, qa-report, review-report, adr
scripts/
  run-mode.sh        # Parse /ceo engine flag (--claude | --opencode | --max)
  track.sh           # Issue-tracker abstraction (local | github | jira)
  open-pr.sh         # Create/merge PR via gh, or print compare URL / use GitHub MCP
  scope.sh           # Rank task-relevant files from the index (retrieve, don't scan)
  scope-guard.sh     # Enforce layer locks in /ceo-subdomain (post-check)
  scope-hook.sh      # PreToolUse hook — block out-of-layer writes in real time
  session-start.sh   # SessionStart warm-up (chmod scripts + refresh index)
  doctor.sh          # Pre-flight health check
  status.sh / metrics.sh   # Task dashboard / throughput metrics
  audit.sh           # Stack-aware dependency vulnerability scan
  changelog.sh       # Assemble CHANGELOG.md from conventional commits
  rollback.sh        # Prepare a safe rollback to a previous release tag
  install-git-hooks.sh     # Install the Conventional-Commits commit-msg hook
  run-command.sh     # Generic AI command runner — routes to claude | opencode | antigravity
  checkpoint.sh      # Task state persistence engine
  devpilot-config.sh # Credential management + Jira validation CLI
  git-flow.sh        # Feature/release/hotfix branch helper
  generate-project-index.sh  # Dynamic codebase index generator
  create-jira-ticket.sh / update-jira-status.sh / …   # Jira helpers (delegate to track.sh when not jira)
  deploy-*.sh                # Per-environment deploy scripts
tests/
  run.sh             # Script test suite (run by .github/workflows/ci.yml)
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

## Testing & CI

devpilot ships its own test suite — `bash tests/run.sh` exercises the helper scripts (`run-mode`, `track`, `scope`, `scope-guard`, `open-pr`). `.github/workflows/ci.yml` runs `shellcheck` + bash syntax checks + the suite on every push and PR, so changes to devpilot itself stay green.

---

## License

MIT — use freely in any project, commercial or otherwise.
