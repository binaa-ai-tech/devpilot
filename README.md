<div align="center">

# devpilot

**Describe the work. An AI team plans it into a deduplicated Jira backlog, sprints it, and ships it — from idea to merged PR.**

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](VERSION)
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
- [Driving the Team](#driving-the-team)
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

devpilot sits between you and your AI coding CLI and runs your work in **two phases**:

1. **Plan** — you describe a feature, bug, task, or requirement; a **PM brain** dedups it against
   your backlog (merging duplicates), then writes it into Jira as **Epic → Story** with a
   self-contained implementation brief. No code.
2. **Build** — it groups ready Stories into **sprints**, recommends which to run first, then a
   structured team — **BA, Team Lead, Frontend, Backend (stack-aware), DB, Integration, QA** —
   ships a whole sprint on one branch → one PR → `develop`.

Or skip the approval step: `/ceo "…"` runs plan → sprint → build end-to-end and walks away.

It is built so a **one-person team can operate like a small company**:

| | |
|---|---|
| 🗂 **Jira backlog with dedup** | New items are deduped/merged against the backlog index; Stories become Epic→Story with full briefs any tool can build from. |
| 🧠 **Task-balanced models** | `/ceo --claude` or `--opencode`; within each family the model is picked per task — power (Opus/GPT-5) vs token-saving (Haiku/4o-mini). |
| 🪙 **Token-lean** | Agents read `core-rules` once + load heavier skills only on demand — a **75–89% cut** in per-spawn skill load, in any repo. |
| 🛡 **Professional gates** | Definition of Ready → sized/sliced → built → tested (DoD) → security/code review → released → postmortem. |
| 🧩 **Any stack** | One stack-aware backend agent + per-stack rule snippets for .NET, Node, Python, Go, Java, Angular, React/Vue, SQL Server, Postgres/MySQL. |
| 📚 **A real operating manual** | 41 process skills: spec-first, definition-of-ready/done, api-design, data-migration-safety, accessibility, i18n, code-review, security-scan, threat-modeling, secrets-management, data-privacy, clean-code, version-control, refactoring, ci-cd, feature-flags, reliability-slo, dependency-management, documentation, test-strategy, test-case-design, test-guard, e2e-testing, performance-testing, auto-merge, database-performance, cost-awareness, debug-method, incident-postmortem, release-discipline, and more. The SDLC contract that ties them together: `.devpilot/process.md`. |
| 🔔 **Operations built in** | Generated per-project CI (`devpilot-ci`) enforcing the gate ladder, one-command branch protection, and webhook/email notifications on sprint DONE / QA BLOCKED (`scripts/notify.sh`). |

**Engines run the same workflow.** Claude uses subagents; opencode (GitHub Copilot) runs the
identical steps as a single-agent loop. Jira Stories are self-contained, so any session, opencode,
or other AI tool can pick up a sprint and build from Jira alone.

---

## Quick Start

**1. Install** — run from the root of your project. The installer is interactive, so it needs a real terminal (it prompts for engine, agents, stack, etc.).

**Recommended — download, then run** (works everywhere; lets you inspect the script first):

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh
```

**Or — one-liner** (the script re-execs itself from `/dev/tty` so the prompts still work when piped):

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash
```

<details>
<summary>Or clone and run locally</summary>

```bash
git clone https://github.com/binaa-ai-tech/devpilot
bash devpilot/install.sh
```
</details>

**Non-interactive** (CI, devcontainers, many repos at once) — accept every recommended default:

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash -s -- --defaults
```

The installer (~5 minutes) detects your AI engines, scans your stack, enables only the agents you
need, configures engine routing / **model assignment** (recommended tiers · one model for the whole
team · a model per team role) / issue tracker / merge policy, and copies the managed files
(`.claude/`, `.opencode/`, `.devpilot/`, `scripts/`, `AGENTS.md`, `CLAUDE.md`).

**📖 Step-by-step walkthrough with a recommendation at every prompt: [docs/setup-guide.md](docs/setup-guide.md).**

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
PLAN                                    BUILD
/dp-plan "add PDF export"               /dp-sprint
  → classify intent                       → group READY Stories into sprints
  → dedup ladder:                         → recommend which to run first
     DUPLICATE / FOLD-IN /              /dp-build sprint-1
     RELATED / UNRELATED                  → one branch
  → spec to git                           → Frontend · Backend · DB · Integration (parallel)
  → Epic→Story to Jira                    → QA every AC  ·  review gate
     (+ self-contained brief)             → one PR → develop  ·  Stories → Done
  (auto; asks only in the gray zone)

/ceo "add PDF export"  =  the whole thing, autonomous (plan → sprint → build).
```

- **Dedup brain** — each new item is matched against `docs/backlog/index.md` (small, always
  loadable); only the top 1–3 candidate specs are read. Merges are reversible Jira links.
- **Self-contained Jira tickets** — every Story's description is a full implementation brief
  (ACs, scope, repo/branch, DoD), rendered as structured ADF, so any tool can build from Jira alone.
- **Engine + model** — resolved per task by `scripts/resolve-engine.sh`; state persists in
  `docs/tasks/` so any engine can resume where another left off.

---

## Driving the Team

Two ways to drive the same engine — both deduplicate the backlog and ship sprint by sprint.

### Plan first, then build (approve as you go)

```
/dp-plan "add CSV export"     → dedups, writes Epic→Story (ready) + self-contained brief
/dp-plan "export to excel"    → detects overlap → FOLD-IN to the same Story
/dp-sprint                    → groups READY Stories, recommends sprint 1
/dp-build sprint-1            → builds the whole sprint → one PR → develop
```

A feature, bug, issue, task, requirement, or enhancement all enter the same way — `/dp-plan`
classifies intent and routes it. Add several over time; the backlog stays deduplicated, and a
**Definition of Ready** gate keeps unclear Stories out of sprints.

### Express — walk away

```
/ceo "add CSV export"
```

Runs plan → sprint → build end to end, autonomously. It stops only to ask **one** thing — a
gray-zone dedup decision — then ships. Auto-merges into `develop` by default
(`merge_policy: pr-only` requires a human merge); you review only for production.

### Engine modes (per run)

A leading flag picks the model **family** (no flag → `engines.coding`):

| Flag | Behaviour |
|------|-----------|
| `/ceo --claude <task>` | Claude models, balanced per task: lite **Haiku** / standard **Sonnet** / power **Opus** |
| `/ceo --opencode <task>` | opencode + GitHub Copilot, balanced per task: **gpt-4o-mini / gpt-4o / gpt-5** |

The model is chosen **per task** by complexity (`resolve-engine.sh`) — power for architectural /
cross-cutting work, lite for simple changes. With `--opencode`, if GitHub Copilot isn't available,
opencode falls back to its own default model.

---

## Command Reference

**Workflow**

| Command | Purpose |
|---------|---------|
| `/ceo [--claude \| --opencode] <description>` | Express — plan → sprint → build, end to end |
| `/dp-plan <feature \| issue \| task \| requirement>` | PM brain: dedup against the backlog, write Epic→Story (no code). Accepts raw text or a Jira key |
| `/dp-sprint` | Group the backlog into sprints, recommend which to run first |
| `/dp-build [sprint]` | Build a whole sprint → one PR → develop |
| `/dp-test [perf] [story \| PR \| diff]` | Derive test cases from ACs → write the missing tests → run the suite |
| `/dp-autofix [PR]` | Drive a PR's CI to green (bounded fix loop) and merge per the `auto-merge` gate ladder |
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
  model_mode: recommended  # recommended (task-balanced tiers) | single (one model for
                           # the whole team) | per-team (a model per role/layer)
  runner: claude       # claude | opencode | antigravity | custom
  fallback: opencode   # engine to use when the primary hits a limit

# Route a single layer to a different engine than engines.coding.
layer_overrides:
  frontend:    ""      # e.g. opencode → generate FE code via opencode (Copilot tiers)
  backend:     ""
  db:          ""
  integration: ""

# Pick a one-word PROFILE (auto | balanced | save) — a preset over the tiers below.
# Per-task routing still chooses the tier; the profile sets which model each maps to.
coding_profile: auto
# Models are chosen PER TASK by complexity tier (power / standard / lite),
# balancing capability vs token cost.
coding_models:
  claude:
    power:    "claude-opus-4-8"            # architectural / cross-cutting / high-risk
    standard: "claude-sonnet-4-6"          # normal feature & bug work
    lite:     "claude-haiku-4-5-20251001"  # simple / mechanical / BA / QA
  opencode:                                 # GitHub Copilot via opencode
    power:    "github-copilot/gpt-5"
    standard: "github-copilot/gpt-4o"
    lite:     "github-copilot/gpt-4o-mini"
    fallback: ""                            # used when Copilot is unavailable ("" = opencode default)

agents:                                     # enable only the layers your stack needs
  ba:          { enabled: true }
  lead:        { enabled: true }
  qa:          { enabled: true }
  frontend:    { enabled: true }
  backend:     { enabled: true }
  db:          { enabled: true }
  integration: { enabled: false }
```

**Entry-point coupling** (enforced by `scripts/resolve-engine.sh` — the single source of truth):

- **Run from Claude Code** → the whole lifecycle stays on the Claude model family. Coding is forced
  to `claude` regardless of `engines.coding`, *unless* a `layer_overrides` entry routes a layer elsewhere.
- **Run from OpenCode / Antigravity** → the entire lifecycle runs natively on that engine's models
  (including local models via Ollama).
- **Per-run override** → a leading flag on `/ceo` forces one engine across every layer for that run.
- **Layer override** → keep orchestration + most coding on Claude, but generate one layer via, e.g.,
  opencode + GitHub Copilot.

**Three model modes** (chosen in the install wizard, switchable anytime):

| `model_mode` | Meaning | Switch with |
|--------------|---------|-------------|
| `recommended` *(default)* | task-balanced tiers via a one-word profile | `/dp-config models save` (claude: `auto \| balanced \| save` · opencode/antigravity: `recommended \| balanced \| save`) |
| `single` | one model for the whole team | `bash scripts/model-profiles.sh single claude claude-sonnet-4-6` |
| `per-team` | a model per role (BA, Team Lead, QA, Frontend, Backend) — or per layer on a non-claude engine | edit `models.*` / `layer_models.*` → `bash scripts/model-profiles.sh sync-agents` |

Profiles are presets over `power / standard / lite`; edit those tiers directly for fine control.
Under the hood: `bash scripts/model-profiles.sh apply claude save` (and `… show` / `… opencode-list`).
Full guidance per scenario: [docs/setup-guide.md](docs/setup-guide.md).

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

The lifecycle is gated end to end — **Ready → built → tested → reviewed → released → postmortem**:

- **Definition of Ready** — entry gate (`definition-of-ready.md`); a Story enters a sprint only when
  it's clear, testable, scoped, sized, and deduped. Unclear Stories stay in the backlog.
- **Definition of Done** — exit gate, per-role checklist (`definition-of-done.md`).
- **Code-review gate** — Team Lead reviews with severity tags (🔴/🟡/🟢); an open 🔴 blocks the PR.
- **Security scan + dependency audit** — `security-scan.md` checklist + `scripts/audit.sh`
  (npm/pip/dotnet/go); new high/critical CVEs block the PR.
- **Layer disciplines** — `api-design` (contracts), `data-migration-safety` (zero-downtime DB),
  `accessibility` (WCAG AA) load on demand for the layers they apply to.
- **QA verdict** — test cases derived per AC (`test-case-design.md`, traceability matrix in the QA
  report); every acceptance criterion has a test; perf budgets proven when in scope
  (`performance-testing.md`); PASS or BLOCKED.
- **Test guard** — `scripts/test-guard.sh` (skill: `test-guard.md`): every changed source file has
  a covering test or a justified exemption; merge gates run it strict (`STRICT=1`) — a gap blocks the PR.
- **Auto-merge ladder** — `auto-merge.md`: build/tests/audit/review/QA/CI all green **on the PR head**
  before a robot merges; `/dp-autofix` fixes red CI within a bounded loop (max 3 push-fix cycles),
  then escalates instead of looping forever.
- **Scope guard** — `scripts/scope-guard.sh` + a real-time `PreToolUse` hook (`scripts/scope-hook.sh`)
  block out-of-layer writes, keeping each agent inside its layer.
- **Server-side enforcement** — the installer generates `.github/workflows/devpilot-ci.yml`
  (stack-aware: build → tests → test-guard → audit, regenerate with `scripts/generate-ci.sh --force`)
  and `scripts/protect-branches.sh` requires that check on `develop`/`main` and blocks force-pushes
  (`merge_policy: pr-only` additionally requires 1 human review).
- **Notifications** — `scripts/notify.sh` pings your webhook (Slack/Teams/Discord-compatible) or
  email on sprint DONE, QA BLOCKED, and autofix escalation; every event also lands in
  `docs/tasks/notifications.log`. Never blocks a flow.
- **Conventional commits** — a `commit-msg` git hook enforces the format locally.
- **Incident postmortem** — `/dp-hotfix` writes a blameless postmortem; action items return to the backlog.

Run `/dp-status health` before starting to catch setup problems early.

---

## Token Efficiency

Designed to stay cheap in **any** repo it's installed into:

- **On-demand skills** — agents read `core-rules.md` once and pull heavier skills only at the step
  that needs them (per core-rules rule #10). That's a **75–89% cut** in per-spawn skill load
  vs. pre-loading; the 838-word `self-heal` loads only on a real failure, not every spawn.
- **Two-tier index** — `docs/project-index.md` is a small bounded map; per-file detail lives in
  `docs/index/*.md` shards that `scope.sh` greps (deterministic bash, zero AI tokens) — agents read
  the map + the top-8 ranked results, never the whole index. Context cost per task is O(1) at any repo size.
- **Scope once, reuse everywhere** — `scope.sh --save <slug>` persists the ranked file list to
  `docs/tasks/<slug>-scope.md` at plan time; lead/dev/QA phases reuse it instead of re-deriving.
- **Hash-gated index freshness** — regeneration is keyed on git content (HEAD + file-list checksum),
  refreshed automatically by post-merge/post-checkout hooks and the SessionStart hook: a free no-op
  when nothing changed, always trustworthy so agents never broad-scan "just in case".
- The dedup brain reads only `docs/backlog/index.md` + the top 1–3 candidate specs.
- **Task-balanced models** — lite tiers (Haiku / gpt-4o-mini) handle simple work so tokens go to the hard parts.
- **Compact handoffs** — agents get a brief (ACs + files to touch), not raw document dumps.

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
  process.md         # The standard dev process — phases, gates, roles (the SDLC contract)
  rules.md           # Router → core-rules + the snippet for your stack
  rules/             # angular, react-vue, dotnet, node, python, go, java, sqlserver, postgres-mysql
  skills/            # Operating manual (README.md index + 41 process skills)
  config/            # models.md — model tier reference
  templates/         # requirements, plan, qa-report, review-report, adr, jira-brief, ticket
scripts/             # Orchestration: engine/model routing, backlog+sprint, Jira (md→ADF), deploy …
tests/run.sh         # Script test suite (run by .github/workflows/ci.yml)
docs/                # Per-task output: requirements, plans, qa, reviews, tasks, backlog, sprints, postmortems
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

**For your project** — the installer generates a stack-aware `devpilot-ci` workflow (Node, .NET,
Python, Go, Java) that runs the gate ladder on every PR, and can apply branch protection so the
check is required. `/dp-autofix` drives that same check to green and merges.

**For devpilot itself** — it ships its own test suite:

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
