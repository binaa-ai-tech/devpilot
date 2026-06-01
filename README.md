<div align="center">

# devpilot

**One command. An AI team ships the whole feature — from BA breakdown to merged PR.**

[![Version](https://img.shields.io/badge/version-2.4.0-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![Engines](https://img.shields.io/badge/engines-Claude%20%7C%20OpenCode%20%7C%20Antigravity-7c3aed.svg)](#configuration)
[![Stacks](https://img.shields.io/badge/stacks-.NET%20%7C%20Node%20%7C%20Python%20%7C%20Go%20%7C%20Java%20%7C%20Angular%20%7C%20React-orange.svg)](#stack-support)

A portable, zero-config multi-agent orchestration layer that installs into any project in minutes.

</div>

---

## Table of Contents

- [What is devpilot?](#what-is-devpilot)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [The Three Multi-Agent Tracks](#the-three-multi-agent-tracks)
- [Command Reference](#command-reference)
- [Configuration](#configuration)
- [Stack Support](#stack-support)
- [Quality Gates](#quality-gates)
- [Token Efficiency](#token-efficiency)
- [Issue Tracking](#issue-tracking)
- [Deploy Pipeline](#deploy-pipeline)
- [Credentials](#credentials)
- [State Persistence](#state-persistence)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Testing & CI](#testing--ci)
- [Contributing](#contributing)
- [License](#license)

---

## What is devpilot?

devpilot sits between you and your AI coding CLI. You describe a task in one command; devpilot
orchestrates a structured engineering team — **Business Analyst, Team Lead, Frontend, Backend
(stack-aware), DB, Integration, and QA** — to take it from requirements all the way to a merged
pull request. You pick the engine; devpilot handles the rest.

It is built so a **one-person team can operate like a small company**:

| | |
|---|---|
| 🧠 **Task-balanced models** | `/ceo --claude` or `--opencode`; within each family the model is picked per task — power vs token-saving. |
| ⚡ **Zero external setup** | Issue tracking defaults to a local file log; GitHub Issues / Jira are opt-in. `gh` is optional. |
| 🪙 **Token-lean** | Agents retrieve only the files relevant to a task and route small work to a fast path — never scan the whole repo. |
| 🧩 **Any stack** | One stack-aware backend agent + per-stack rule snippets for .NET, Node, Python, Go, Java, Angular, React/Vue, SQL Server, Postgres/MySQL. |
| 📚 **A real operating manual** | Process skills for code review, testing, debugging, slicing, tech-debt, observability, release discipline, and status reporting. |

**All three AI engines run the same workflow.** Claude uses subagents; OpenCode and Antigravity
run the identical steps as a single-agent loop — no workarounds. State is persisted so any engine
can resume where another left off.

---

## Quick Start

**1. Install** — run from the root of your project:

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh
```

<details>
<summary>Or clone and run locally</summary>

```bash
git clone https://github.com/binaa-ai-tech/devpilot
bash devpilot/install.sh
```
</details>

The installer (~5 minutes) detects your AI engines, scans your stack, enables only the agents you
need, configures engine routing / issue tracker / merge policy, and copies the managed files
(`.claude/`, `.opencode/`, `.devpilot/`, `scripts/`, `AGENTS.md`, `CLAUDE.md`).

**2. Run your first task:**

```bash
/ceo "add rental agreement PDF export"
```

That's it — the team takes it from requirements to PR.

**3. Update devpilot later** without touching your config:

```bash
bash install.sh --update   # refreshes .claude/, .devpilot/, scripts/
                           # never overwrites project.config.md or .devpilot/config.sh
```

---

## How It Works

```
You → /ceo "add rental agreement PDF export"
           │
           ▼
   ┌────────────────────────────────────────────────────┐
   │  devpilot orchestration layer                      │
   │                                                    │
   │  Engine routing  →  claude | opencode | antigravity│
   │  State engine    →  docs/tasks/<KEY>-checkpoint.json│
   │  Credential CLI  →  scripts/devpilot-config.sh     │
   └────────────────────────────────────────────────────┘
           │
           ▼
   BA → Team Lead → [Frontend | Backend | DB | Integration] → QA → PR
```

`/ceo` first **sizes** the task — trivial work takes a fast fix path, single-layer work runs
layer-locked, and multi-layer work runs the full team flow. Small changes never pay for the full
five-phase pipeline.

---

## The Three Multi-Agent Tracks

### Track 1 — Full CEO Process · `/ceo`

End-to-end autonomous engineering. The BA reads the codebase and writes requirements, the Team
Lead creates the ticket and branch, implementation agents build the code, QA verifies every
acceptance criterion, and the Team Lead opens and merges the PR.

```
/ceo "description"
     │
     ▼
[BA]        Reads project-index → requirements + domain model
[Team Lead] Ticket → feature branch → implementation plan
[Parallel]  Frontend · Backend · DB · Integration   (only enabled layers)
[QA]        Verifies all ACs → QA report → fixes blockers
[Team Lead] Code review → PR → auto-merge into base_branch
     │
     ▼
✅  Merged + ticket Done + promote commands printed
```

**No stopping, no questions, no manual steps.** Auto-merges into `develop` by default
(set `merge_policy: pr-only` to require a human merge); you review only for production.

Per-run engine modes — pick how a task runs with a leading flag (no flag → `engines.coding`):

| Flag | Behaviour |
|------|-----------|
| `/ceo --claude <task>` | All phases + coding on Claude models (balanced per task: Haiku/Sonnet/Opus) |
| `/ceo --opencode <task>` | Claude orchestrates; opencode writes code with GitHub Copilot models (balanced per task) |

Within the chosen family the model is selected **per task** by `resolve-engine.sh` — power for
architectural/cross-cutting work, lite for simple changes. With `--opencode`, if GitHub Copilot
isn't available, opencode falls back to its own default model.

### Plan-only vs Express

Two ways to drive the same engine:

- **Plan first (approve, then build):** `/dp-plan <thing>` runs the PM brain — it dedups the
  new item against the backlog (merging duplicates), then writes Epic→Story to Jira. No code.
  When the backlog looks right, `/dp-sprint` groups it and recommends an order, and
  `/dp-build <sprint>` ships a whole sprint on one branch → one PR → `develop`.
- **Express (walk away):** `/ceo <thing>` does plan → sprint → build end to end, stopping only
  to ask one thing — a gray-zone dedup decision.

A bug, an issue, a task, a requirement, and an enhancement all enter the same way — `/dp-plan`
classifies intent and routes it. Add several over time; the backlog stays deduplicated.

---

## Command Reference

**Workflow**

| Command | Purpose |
|---------|---------|
| `/ceo [--claude \| --opencode] <description>` | Express — plan → sprint → build, end to end |
| `/dp-plan <feature \| issue \| task \| requirement>` | PM brain: dedup against the backlog, write Epic→Story (no code). Accepts raw text or a Jira key |
| `/dp-sprint` | Group the backlog into sprints, recommend which to run first |
| `/dp-build [sprint]` | Build a whole sprint → one PR → develop |
| `/dp-review-fix <PR>` | Read PR review comments → apply fixes → push |

The six team agents (`team-ba`, `team-lead`, `team-frontend`, `team-backend`, `team-dotnet`,
`team-qa`) are spawned automatically by the workflow commands — no manual slash wrappers.

**Config & deploy**

| Command | Purpose |
|---------|---------|
| `/dp-config [models \| wizard \| index]` | Set models / re-run the wizard / refresh the project index |
| `/dp-status [health \| board \| metrics]` | Health check · task dashboard · throughput metrics |
| `/dp-release <sit \| uat \| prd> [version]` | Promote DEV→SIT→UAT→PRD |
| `/dp-hotfix <ticket> <slug> <version>` · `/dp-rollback [version]` | Emergency fix · roll back |
| `bash install.sh --update` | Refresh devpilot itself (config preserved) |

---

## Configuration

`project.config.md` is the single source of truth for all routing decisions. Commit it to git.

```yaml
project_name: my-app
base_branch: develop   # PRs target & DEV deploys from this; defaults to develop when it exists

tracker:
  type: local          # local | github | jira  — local = zero setup, logs to docs/tasks/

merge_policy: auto     # auto = devpilot squash-merges the PR | pr-only = a human merges
language: en           # human language for BA/QA/review docs (code stays English)

stack:
  frontend: angular    # angular | react | vue | nextjs | none
  backend:  dotnet     # dotnet | node | python | go | java | none
  database: sqlserver  # sqlserver | postgres | mysql | none
  mobile:   none

engines:
  orchestrator: claude # always claude — Claude Code drives orchestration
  coding: claude       # claude | opencode | antigravity
  runner: claude       # claude | opencode | antigravity | custom
  fallback: opencode   # engine to use when the primary hits a limit

# Route a single layer to a different engine than engines.coding.
layer_overrides:
  frontend:    ""      # e.g. opencode → FE via coding_models.opencode.frontend
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

**Entry-point coupling** (enforced by `scripts/resolve-engine.sh` — the single source of truth):

- **Run from Claude Code** → the whole lifecycle stays on the Claude model family. Coding is forced
  to `claude` regardless of `engines.coding`, *unless* a `layer_overrides` entry routes a layer elsewhere.
- **Run from OpenCode / Antigravity** → the entire lifecycle runs natively on that engine's models
  (including local models via Ollama).
- **Per-run override** → a leading flag on `/ceo` forces one engine across every layer for that run.
- **Layer override** → keep orchestration + most coding on Claude, but generate one layer via, e.g.,
  opencode + GitHub Copilot.

Change a single agent's model without editing the file:

```bash
/dp-config models backend github-copilot/gpt-4o
/dp-config models                              # interactive
```

---

## Stack Support

A single **stack-aware backend agent** adapts to your language; rules are split into per-stack
snippets so agents read only what applies (`.devpilot/rules/<stack>.md`, routed by `.devpilot/rules.md`).

| Layer | Supported |
|-------|-----------|
| Frontend | Angular · React · Vue · Next.js |
| Backend | .NET · Node/TypeScript · Python · Go · Java |
| Database | SQL Server · PostgreSQL · MySQL |

---

## Quality Gates

Nothing merges until it passes:

- **Definition of Done** — per-role checklist (`.devpilot/skills/definition-of-done.md`).
- **Code-review gate** — Team Lead reviews the diff with severity tags (🔴/🟡/🟢); an open 🔴 blocks the PR.
- **Security scan + dependency audit** — checklist over the diff plus `scripts/audit.sh`
  (npm/pip/dotnet/go); new high/critical CVEs block the PR.
- **QA verdict** — every acceptance criterion has a test; PASS or BLOCKED.
- **Scope guard** — `scripts/scope-guard.sh` (post-check) **and** a real-time `PreToolUse` hook
  (`scripts/scope-hook.sh`) that blocks out-of-layer writes, keeping each agent inside its layer.
- **Conventional commits** — a `commit-msg` git hook enforces the format locally.
- **Merge policy** — `auto` (squash-merge) or `pr-only` (a human merges); production always needs sign-off.

Run `/dp-status health` before starting to catch setup problems early.

---

## Token Efficiency

devpilot works on **only the code relevant to the task** — never the whole repo:

- **Project index** (`scripts/generate-project-index.sh`) — a fast-scan map, auto-refreshed on session start.
- **Scoped retrieval** (`scripts/scope.sh`) — ranks the few files relevant to a task; agents read those.
- **Size routing** — small work skips the full five-phase docs pipeline.
- **Compact handoffs** — agents get a brief (ACs + files to touch), not raw document dumps.
- **On-demand skills** — agents always load `core-rules.md` and pull heavier skills only when needed.

---

## Issue Tracking

Zero setup by default. Tracking works at **two altitudes** so a task is fully auditable without
flooding the ticket (see `core-rules` #11):

- **`docs/tasks/<KEY>.md`** — the live, per-step log: who/what/when, decisions, and deviations.
  Durable, diffable, and it survives even if the ticket is archived.
- **The ticket** (Jira/GitHub) — only two routine comments: a **start** comment and a single
  **DONE** summary, plus status transitions. A **QA BLOCKED** / hard-failure comment is the only
  exception. Routine progress (plan-complete, impl-complete, QA-passed, merged) goes to the task
  log, not the ticket — it would just duplicate the PR and the DONE block.

Switch backends anytime via `scripts/track.sh` without touching a command:

| `tracker.type` | Behaviour | Setup |
|----------------|-----------|-------|
| `local` *(default)* | Everything in `docs/tasks/<KEY>.md` — no external service | none |
| `github` | Start + DONE on GitHub Issues via `gh`; detail in the task log | `gh auth login` (falls back to `local`) |
| `jira` | Start + DONE on Jira Cloud; detail in the task log | credentials in `.devpilot/config.sh` |

---

## Deploy Pipeline

After CI deploys to DEV, promote through environments:

| Command | Stage | Trigger |
|---------|-------|---------|
| `/dp-release sit <version>` | SIT | DEV testing passed |
| `/dp-release uat` | UAT | SIT QA passed |
| `/dp-release prd <version>` | PRD | UAT signed off — **opens PR, requires your review** |
| `/dp-hotfix <ticket> <slug> <ver>` | Emergency | Production incident |
| `/dp-rollback [version]` | Rollback | Revert to a previous release tag |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), fixes → bump PATCH (`1.0.0 → 1.0.1`).

<details>
<summary>One-time deploy setup (GitHub secrets + environments)</summary>

**GitHub Secrets** (Repo → Settings → Secrets → Actions):
`DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`

**GitHub Environments** (Repo → Settings → Environments): `dev`, `sit`, `uat`, `prd`
</details>

---

## Credentials

`scripts/devpilot-config.sh` manages all credentials in `.devpilot/config.sh` (gitignored) with
live Jira validation. **Never edit that file by hand.**

```bash
bash scripts/devpilot-config.sh show                                # all values, tokens masked
bash scripts/devpilot-config.sh set jira_api_token=<new-token>      # update + validate live
bash scripts/devpilot-config.sh set jira_base_url=https://your-org.atlassian.net
bash scripts/devpilot-config.sh validate                            # full connectivity check
```

`validate` makes a live Jira API call: `200 OK` (valid) · `401` (rotate token) · `403` (insufficient
permissions) · `000` (network/URL issue).

---

## State Persistence

Every task that touches the checkpoint engine saves to `docs/tasks/<KEY>-checkpoint.json`. If the
primary engine hits a rate limit, the fallback engine reads the checkpoint and resumes from the exact
phase that was interrupted — no re-running BA, no re-generating plans.

```bash
bash scripts/checkpoint.sh show KEY-123    # inspect current state
bash scripts/checkpoint.sh latest          # find the most recent in-progress task
```

---

## Project Structure

```
.claude/
  commands/          # /ceo + /dp-* workflow, deploy & config commands
  agents/            # team-ba, team-lead, team-frontend, team-backend, team-dotnet, team-qa
  settings.json      # SessionStart hook → scripts/session-start.sh
.opencode/
  config.json        # OpenCode project config — points to AGENTS.md and .devpilot/rules.md
.devpilot/
  rules.md           # Router → core-rules + the snippet for your stack
  rules/             # angular, react-vue, dotnet, node, python, go, java, sqlserver, postgres-mysql
  skills/            # Operating manual (README.md index + 16 process skills)
  config/            # models.md — per-agent model reference
  templates/         # requirements, plan, qa-report, review-report, adr, ticket
scripts/             # Orchestration: engine routing, tracking, scoping, deploy, Jira, checkpoints …
tests/run.sh         # Script test suite (run by .github/workflows/ci.yml)
docs/                # Per-task output: requirements, plans, qa, reviews, tasks, domain-models, adrs
AGENTS.md            # OpenCode/Antigravity project context
CLAUDE.md            # Claude Code project context
project.config.md    # Per-project config — engine routing, models, stack, agents
install.sh           # One-command installer
```

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | Orchestration — BA, planning, QA, review |
| `git` | Yes | Branch management |
| [GitHub CLI (`gh`)](https://cli.github.com) | Optional | PR auto-merge; without it `open-pr.sh` prints a compare URL |
| `jq` or `python3` | Optional | JSON operations in checkpoint/config scripts |
| [OpenCode](https://opencode.ai) | Optional | If `engines.coding: opencode` or `/ceo --opencode` |
| Antigravity | Optional | If `engines.coding: antigravity` |

---

## Testing & CI

devpilot ships its own test suite:

```bash
bash tests/run.sh    # exercises run-mode, track, scope, scope-guard, open-pr, resolve-engine, …
```

`.github/workflows/ci.yml` is cost-tiered: pull requests run only the cheap gate (`shellcheck` +
bash syntax checks + the suite), while the full pipeline runs on push to `base_branch` after a PR
merges — so PR iterations stay fast and expensive workflows fire once per merge.

---

## Contributing

1. Branch from `main` — `feature/<slug>` or `fix/<slug>`. Never commit to `main` directly.
2. Keep changes focused; one concern per commit.
3. Use [Conventional Commits](https://www.conventionalcommits.org) — `feat:`, `fix:`, `chore:`, etc.
   (enforced by the local `commit-msg` hook).
4. Run `bash tests/run.sh` and make sure it passes before opening a PR.
5. Open a PR against `main`; CI must be green.

---

## License

[MIT](#license) — use freely in any project, commercial or otherwise.
