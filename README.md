<div align="center">

# DevPilot

**An AI delivery team for Angular + .NET, built on Claude Code. Describe the requirement; the team refines it, builds it, tests it end to end, reviews it, and merges it.**

[![Version](https://img.shields.io/badge/version-5.0.0-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![Runs on](https://img.shields.io/badge/runs%20on-Claude%20Code-7c3aed.svg)](#requirements)
[![Stack](https://img.shields.io/badge/stack-Angular%20%7C%20.NET%20%7C%20SQL%20Server-orange.svg)](#stack)

Installs into an existing Angular / ASP.NET Core repository in minutes and runs the same gated
SDLC a large engineering organization would: backlog refinement, sprints, code review, QA,
protected branches, DEV → SIT → UAT → PRD promotion, and postmortems.

</div>

---

## Contents

- [Why DevPilot](#why-devpilot)
- [Quick start](#quick-start)
- [Commands — one per team role](#commands--one-per-team-role)
- [How a requirement flows](#how-a-requirement-flows)
- [The delivery process](#the-delivery-process)
- [Stack](#stack)
- [Quality and governance gates](#quality-and-governance-gates)
- [DevOps pipeline](#devops-pipeline)
- [Configuration](#configuration)
- [Token efficiency](#token-efficiency)
- [Issue tracking](#issue-tracking)
- [Enterprise rollout](#enterprise-rollout)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)
- [Upgrading from 4.x](#upgrading-from-4x)
- [Contributing](#contributing)

---

## Why DevPilot

| | |
|---|---|
| 🚀 **One command, requirement → merged** | `/dp-deliver "…"` runs BA → sprint → plan → Angular + .NET build → QA → review → PR → merge. It stops only for a gray-zone backlog-dedup question. |
| 👥 **Commands map to team roles** | Product Owner, Scrum Master, developers, QA, Tech Lead, DevOps, on-call. Each role has one command, so the team adopts it without learning a new process. |
| 🧪 **Tested at every layer** | Vitest (Angular) · xUnit + `WebApplicationFactory` on real SQL Server via Testcontainers (.NET) · OpenAPI contract checks · Playwright UI journeys with accessibility, visual, and mobile checks. |
| 🛡 **Enterprise gates by default** | Definition of Ready/Done, test guard, severity-tagged code review, security scan, dependency audit, protected branches, and a human-approved production release. |
| 🪙 **Token-lean** | Skills load only when needed. The index is sharded, and test output is summarized so agents read failures, not logs. Each task goes to Haiku, Sonnet, or Opus by complexity. |
| 🗂 **A backlog that stays clean** | Every new item is checked against the backlog: duplicates are merged and overlaps folded into existing Stories. Each Jira Story carries a self-contained implementation brief. |

---

## Quick start

**1. Install** from the root of your Angular / .NET repository:

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh
```

Non-interactive (CI, devcontainers, rolling out to many repos): append `-s -- --defaults` to a
piped install, or run `bash install.sh --defaults`. The 6-step wizard detects your stack, enables
the matching agents, sets the Claude model profile, tracker, and merge policy, then offers to
generate CI and protect `develop`/`main`.
Full walkthrough: **[docs/setup-guide.md](docs/setup-guide.md)**.

**2. Verify:** `/dp-status health` (fix anything flagged with `/dp-setup fix`).

**3. Deliver:**

```bash
/dp-deliver "add a CSV export to the orders page"            # → merged into develop
/dp-deliver "add a CSV export to the orders page" --to sit   # → merged + SIT release cut
```

**Update later**, keeping your config: `bash install.sh --update`.

---

## Commands — one per team role

| Role | Command | What it does |
|------|---------|--------------|
| **Whole team** | `/dp-deliver <requirement> [--to sit]` | End to end: refine → sprint → build → test → review → merge (→ SIT). `/dp-deliver resume` continues after an interruption. |
| **Product Owner / BA** | `/dp-refine <requirement \| Jira key>` | Classify, dedup against the backlog, write Epic → Story with testable ACs. No code. |
| **Scrum Master** | `/dp-sprint` | Group READY Stories into sprints, recommend the run order. |
| **Developers** | `/dp-build [sprint]` | Angular + .NET agents build the sprint in parallel on one branch → one PR. |
| **QA** | `/dp-test [ui \| perf] [story \| PR \| diff]` | Derive cases from ACs, then write unit, integration, and Playwright tests and run them. `ui` = full UI pass. |
| **Tech Lead** | `/dp-pr [PR]` | Apply review comments, drive CI to green (bounded), merge per policy. |
| **DevOps** | `/dp-release <sit \| uat \| prd \| rollback> [version]` | Promote DEV → SIT → UAT → PRD, or roll production back. |
| **On-call** | `/dp-hotfix <ticket> <slug> <version>` | Emergency fix from the deployed tag, followed by a blameless postmortem. |
| **Everyone** | `/dp-status [health \| board \| metrics]` | Health check · task board · throughput. |
| **Admin** | `/dp-setup [fix \| models \| wizard \| index]` | Repair config, switch the Claude model profile, refresh the index. |

Agents (`team-ba`, `team-lead`, `team-frontend`, `team-dotnet`, `team-qa`) are spawned by these
commands. You never call them directly.

### Everyday situations

| Situation | Type |
|-----------|------|
| New feature or bug | `/dp-deliver "…"` (bugs get a failing-test-first flow automatically) |
| Approve the plan before code | `/dp-refine "…"` → `/dp-sprint` → `/dp-build` |
| Many ideas at once | several `/dp-refine` → `/dp-sprint` → `/dp-build sprint-1` |
| Thin tests / full UI regression | `/dp-test <story>` · `/dp-test ui <story>` |
| PR red or has review comments | `/dp-pr <PR>` |
| Ship to test / production | `/dp-release sit 1.4.0` → `/dp-release uat` → `/dp-release prd 1.4.0` |
| Production incident | `/dp-hotfix …` · `/dp-release rollback` |
| Spend too high | `/dp-setup models save` |

---

## How a requirement flows

```
/dp-deliver "add CSV export"
  │
  ├─ REFINE   BA: classify → dedup vs docs/backlog/index.md → spec + Epic→Story (Jira/GitHub/local)
  ├─ SPRINT   feature → its own sprint · bug → the active sprint · P0/P1 → refused, use /dp-hotfix
  ├─ PLAN     Team Lead: files per layer, API contract, test layer per AC, ADRs
  ├─ BUILD    team-dotnet (API · EF Core · migrations · OpenAPI)  ║  team-frontend (Angular · generated client)
  ├─ QA       case matrix per AC → Vitest · xUnit + SQL Server · Playwright journeys + axe
  ├─ REVIEW   code-review · security · performance · architecture · test guard (strict)
  ├─ MERGE    PR → develop, auto-merge ladder green on the head commit (bounded fix loop)
  └─ PROMOTE  (--to sit) release branch → SIT      ·  UAT and PRD stay human-gated
```

---

## The delivery process

The full contract is `.devpilot/process.md`. Each phase has an exit gate, and a failed gate sends
work **back one phase, never forward with a TODO**.

| Phase | Owner / command | Exit gate |
|-------|-----------------|-----------|
| Intake | PO · `/dp-refine` | Classified, deduped, Epic→Story exists (hard-gated by `jira-guard.sh`) |
| Ready | BA | Definition of Ready: testable ACs, sized, sliced |
| Sprint | Scrum Master · `/dp-sprint` | Only READY Stories; sprint goal + run order |
| Build | Developers · `/dp-build` | One branch per sprint; agents stay in their layer; build never red |
| Verify | QA · `/dp-test` | Every AC tested; UI ACs have Playwright journeys; verdict PASS |
| Merge | Tech Lead · `/dp-pr` | Auto-merge ladder green on the PR head |
| Release | DevOps · `/dp-release` | Same artifact promoted DEV→SIT→UAT→PRD; PRD human-approved |
| Operate | On-call · `/dp-hotfix` | Blameless postmortem; action items back to Intake |

---

## Stack

| Layer | Technology | How it's tested |
|-------|-----------|-----------------|
| Frontend | Angular 21+ (standalone, signals, zoneless-ready) | Vitest + TestBed, `HttpTestingController`, harnesses |
| Backend | ASP.NET Core (.NET 8+) — controllers or minimal APIs | xUnit unit tests + `WebApplicationFactory` integration tests |
| Data | EF Core + SQL Server | Testcontainers (real SQL Server) + Respawn — never the InMemory provider |
| Contract | OpenAPI committed → Angular client generated | Snapshot test + breaking-change check (`oasdiff`) |
| UI / E2E | The running app + API | Playwright: journeys, auth-once, API seeding, axe, visual, mobile |

Every suite runs through `scripts/run-tests.sh`. The full log goes to `.devpilot/logs/`; agents
read one PASS/FAIL line plus the failures.

**Skills** (`.devpilot/skills/`, 23, loaded only when needed):
- Angular: `angular-dev`, `angular-testing`, `accessibility`
- .NET: `dotnet-api`, `efcore-sqlserver`, `dotnet-testing`, `api-contract`
- QA: `test-case-design`, `test-strategy`, `ui-e2e-playwright`, `token-lean-testing`, `test-guard`, `performance`
- Gates and operations: `definition-of-ready`, `definition-of-done`, `architecture-guard`, `code-review`, `security-scan`, `auto-merge`, `release-ops`, `self-heal`, `estimation-and-slicing`, `core-rules`

---

## Quality and governance gates

- **Definition of Ready / Done**: entry and exit gates per role.
- **Test guard**: every changed source file has a covering test. Merge gates run it strict (`STRICT=1`).
- **Code review**: Team Lead review with 🔴/🟡/🟢 severity. An open 🔴 blocks the merge.
- **Security**: threat model at design time, then a diff checklist covering injection, auth and
  ownership, secrets, PII and dependencies. `scripts/audit.sh` blocks new high or critical CVEs.
- **API contract**: breaking changes need a new version. The spec and the Angular client land in the same PR.
- **Auto-merge ladder**: build, tests, audit, review, QA and CI must be green **on the head commit**.
  The fix loop is capped at 3 cycles, after which it escalates.
- **Scope guard**: a `PreToolUse` hook blocks agents from writing outside their layer.
- **Server-side enforcement**: a generated `devpilot-ci` workflow. Branch protection requires it on
  `develop`/`main` and blocks force-pushes. `pr-only` additionally requires a human review.
- **Audit trail**: `docs/tasks/<KEY>.md` holds the step log, `docs/qa/` the verdicts, and the PR body
  the review. Each ticket gets exactly one start comment and one DONE comment.
- **Conventional commits**: enforced by a `commit-msg` hook.

---

## DevOps pipeline

| Stage | Command | Gate |
|-------|---------|------|
| DEV | automatic after merge to `develop` | CI green |
| SIT | `/dp-release sit <version>` (or `/dp-deliver … --to sit`) | DEV smoke passed |
| UAT | `/dp-release uat` | SIT deploy + smoke green; environment approval |
| PRD | `/dp-release prd <version>` | UAT sign-off, human approval of the `production` environment |
| Rollback | `/dp-release rollback [version]` | Dry run first; never rewrites history |
| Hotfix | `/dp-hotfix <ticket> <slug> <version>` | Branch from the deployed tag; UAT before PRD |

The pipeline builds the artifact once and promotes that same artifact through each environment.
Releases use SemVer (MINOR for features, PATCH for fixes), and every release gets a changelog
section and a tag.

<details>
<summary>One-time deploy setup</summary>

GitHub Secrets: `DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`.
GitHub Environments: `dev`, `sit`, `uat`, `prd`. Put required reviewers on `uat` and `prd`.
</details>

---

## Configuration

`project.config.md` is the single source of truth. Commit it.

```yaml
project_name: my-app
ticket_prefix: APP
base_branch: develop          # PRs target this; DEV deploys from it
tracker:
  type: jira                  # local | github | jira
merge_policy: auto            # auto = the team merges green PRs · pr-only = a human merges
language: en                  # BA/QA docs language (code stays English)

stack:
  frontend: angular           # angular | none
  backend: dotnet             # dotnet | none
  database: sqlserver         # sqlserver | none

model_policy:
  coding_profile: auto        # auto (Opus for hard work) | balanced (no Opus) | save (Haiku-first)
  model_mode: recommended     # recommended | single | per-team

coding_models:
  claude:
    power:    "claude-opus-5-5"            # architectural / cross-cutting / high-risk
    standard: "claude-sonnet-5"            # normal feature & bug work
    lite:     "claude-haiku-4-5-20251001"  # simple changes, BA, QA
```

Switch models anytime: `/dp-setup models <auto|balanced|save>`, one model for everyone with
`bash scripts/model-profiles.sh single <model-id>`, or per role by editing `models.*` then running
`bash scripts/model-profiles.sh sync-agents`. Reference: `.devpilot/config/models.md`.

---

## Token efficiency

- **Skills load only when needed.** Agents read `core-rules.md` once and load a skill only at the step that needs it.
- **Two-tier index.** `docs/project-index.md` is a small map. Per-file detail lives in shards that
  `scope.sh` greps without spending AI tokens. Each task reads the top 3–8 files, never the whole repo.
- **Scope once.** `scope.sh --save` persists the file list at plan time, and every later phase reuses it.
- **Hash-gated index.** The index regenerates only when repo content changes.
- **Summarized test output.** `run-tests.sh` returns failures only. Agents re-run just the failing tests while fixing.
- **Per-task models.** Haiku handles light work and Opus only architectural work.
- **Small backlog reads.** Dedup reads the backlog index plus the top 1–3 candidate specs.

---

## Issue tracking

| `tracker.type` | Behaviour | Setup |
|----------------|-----------|-------|
| `local` *(default)* | Everything in `docs/tasks/<KEY>.md` | none |
| `github` | GitHub Issues via `gh` | `gh auth login` |
| `jira` | Jira Cloud: Epic → Story, sprints, ADF briefs | `bash scripts/devpilot-config.sh set jira_api_token=<token>` (validated live) |

Credentials live in `.devpilot/config.sh` (gitignored), managed by `scripts/devpilot-config.sh`.

---

## Enterprise rollout

1. **Pilot (one repo, one week).** Install with defaults and `merge_policy: pr-only`. Run real
   Stories through `/dp-deliver` and review every PR it opens.
2. **Team.** Switch to `tracker: jira`, apply branch protection and CI (the installer offers both),
   add CODEOWNERS, and set `NOTIFY_WEBHOOK` to your Teams or Slack channel.
3. **Organization.** Roll out or update every repository with one PR each:
   `bash scripts/update-org.sh <org> --merge [--install-missing]`.
   Move to `merge_policy: auto` once the gates have earned trust. Production stays human-approved.

These hold at every stage: never weaken a gate to get a change through, and PRD is always human-approved.

---

## Project structure

```
.claude/
  commands/        # the 10 /dp-* commands
  agents/          # team-ba · team-lead · team-frontend · team-dotnet · team-qa
  settings.json    # SessionStart + scope-guard hooks
.devpilot/
  process.md       # the SDLC contract — phases, gates, roles
  rules.md         # router → rules/angular.md · rules/dotnet.md · rules/sqlserver.md
  skills/          # 23 skills (README.md is the index)
  templates/       # requirements, plan, QA report, review report, ADR, Jira brief
  config/models.md # Claude model tiers and profiles
scripts/           # tracker (Jira/GitHub/local), git-flow, tests, CI, deploy, doctor
docs/              # per-task output: requirements, plans, qa, reviews, tasks, backlog, sprints
CLAUDE.md          # Claude Code project context
project.config.md  # team + model configuration
install.sh         # installer and --update
```

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) (CLI, desktop, IDE, or web) | Yes | Runs the whole team |
| `git` | Yes | Branching and releases |
| [GitHub CLI](https://cli.github.com) `gh` | Recommended | PR automation (Claude Code on the web uses the GitHub MCP tools instead) |
| .NET SDK, Node.js, Docker | For your project | Build and test; Docker runs the SQL Server test container |
| `jq` or `python3` | Optional | Checkpoint and config scripts |

---

## Troubleshooting

Start with `/dp-status health`. Every warning prints its fix, and `/dp-setup fix` applies them.

| Symptom | Fix |
|---------|-----|
| Jira 401 / tickets not created | `bash scripts/devpilot-config.sh validate`, then rotate the token (tracking falls back to local meanwhile) |
| Agent model differs from config | `bash scripts/model-profiles.sh sync-agents` |
| Stale scope results | `bash scripts/generate-project-index.sh --force` |
| Test guard blocks a file that needs no test | Justify the exemption in the PR description. Never drop `STRICT=1` |
| Integration tests fail with a Docker error | Start Docker. Testcontainers needs it, and the InMemory provider is not a substitute |
| Hit a Claude usage limit mid-run | Nothing is lost: work is checkpointed and pushed. Run `/dp-deliver resume` after the reset |
| CI red on the PR | `/dp-pr <PR>` |
| Doctor warns about a legacy `engines:` block | Delete it from `project.config.md`; models live under `model_policy` / `coding_models` |

---

## Upgrading from 4.x

DevPilot 5 runs on Claude only and uses role-based command names. `bash install.sh --update`
installs the new commands and removes the retired files. Then delete the old `engines:`,
`layer_overrides:`, `layer_models:` and `fallback:` blocks from `project.config.md` and add
`model_policy:` (see [Configuration](#configuration)).

| 4.x | 5.x |
|-----|-----|
| `/ceo` | `/dp-deliver` |
| `/dp-plan` | `/dp-refine` |
| `/dp-autofix`, `/dp-review-fix` | `/dp-pr` |
| `/dp-rollback` | `/dp-release rollback` |
| `/dp-config` | `/dp-setup` |
| `--claude` / `--opencode`, OpenCode, Antigravity, `AGENTS.md`, `scripts/ceo.sh` | removed |

---

## Contributing

1. Branch from `main` (`feature/<slug>` or `fix/<slug>`) and keep one concern per commit.
2. Use [Conventional Commits](https://www.conventionalcommits.org).
3. Run `bash tests/run.sh` before opening a PR. CI runs shellcheck, a bash syntax check and the suite.

## License

[MIT](#license). Use it freely in any project, commercial or otherwise.
