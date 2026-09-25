<div align="center">

# DevPilot

**An AI development team for Angular + .NET projects, running inside Claude Code.**

You write what you need in one sentence. DevPilot plans it, writes the code, tests it, reviews it, and merges it.

[![Version](https://img.shields.io/badge/version-5.0.0-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![Runs on](https://img.shields.io/badge/runs%20on-Claude%20Code-7c3aed.svg)](#what-you-need)
[![Stack](https://img.shields.io/badge/stack-Angular%20%7C%20.NET%20%7C%20SQL%20Server-orange.svg)](#what-you-need)

</div>

---

## In 30 seconds

```bash
/dp-deliver "add a CSV export button to the orders page"
```

That one command does what a full team does:

1. **Plans**: writes the user story and acceptance criteria, and checks the backlog for duplicates.
2. **Builds**: a .NET developer agent writes the API and database changes; an Angular developer agent writes the UI.
3. **Tests**: writes and runs unit tests, API tests on a real SQL Server, and browser (UI) tests.
4. **Reviews**: checks code quality, security, performance, and missing tests.
5. **Merges**: opens a pull request into `develop` and merges it once every check is green.

Production is never touched without your approval.

---

## Contents

1. [Install](#1-install)
2. [The 10 commands](#2-the-10-commands)
3. [Common tasks: what to type](#3-common-tasks-what-to-type)
4. [What happens when you run /dp-deliver](#4-what-happens-when-you-run-dp-deliver)
5. [Testing](#5-testing)
6. [Releasing to SIT, UAT, and production](#6-releasing-to-sit-uat-and-production)
7. [Safety checks (quality gates)](#7-safety-checks-quality-gates)
8. [Configuration](#8-configuration)
9. [What you need](#what-you-need)
10. [Troubleshooting](#troubleshooting)
11. [Upgrading from 4.x](#upgrading-from-4x)

---

## 1. Install

Run this in the **root folder of your project** (the folder with your `.sln` or `angular.json`):

```bash
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh
bash /tmp/devpilot-install.sh
```

The installer asks 6 short questions. **Press Enter to accept the recommended answer** for each one.
Want no questions at all? Run `bash /tmp/devpilot-install.sh --defaults`.

Then open the project in Claude Code and check the setup:

```bash
/dp-status health     # checks everything; each warning tells you how to fix it
/dp-setup fix         # fixes the warnings for you, asking one question at a time
```

Commit the new files, and you're ready:

```bash
git add -A && git commit -m "chore: install devpilot"
```

**Update DevPilot later** (your settings are kept): `bash install.sh --update`

More detail on every installer question: [docs/setup-guide.md](docs/setup-guide.md).

---

## 2. The 10 commands

Each command matches a role in a normal development team.

| Command | Team role | What it does |
|---------|-----------|--------------|
| `/dp-deliver "…"` | The whole team | **Everything, end to end**: plan → code → test → review → merge. Use this most of the time. |
| `/dp-plan "…"` | Product Owner / BA | Turns a requirement into user stories with acceptance criteria. **Writes no code.** |
| `/dp-sprint` | Scrum Master | Groups the planned stories into sprints and tells you which sprint to build first. |
| `/dp-build [sprint]` | Developers | Writes the code for a whole sprint on one branch and opens one pull request. |
| `/dp-test [ui\|perf] <story>` | QA | Writes the missing tests and runs them. `ui` = full browser testing. `perf` = load testing. |
| `/dp-pr <PR number>` | Tech Lead | Fixes review comments and failing CI on a pull request, then merges it. |
| `/dp-release <stage>` | DevOps | Deploys to `sit`, `uat`, or `prd`, or runs `rollback`. |
| `/dp-hotfix …` | On-call | Emergency fix for a production bug. |
| `/dp-status` | Everyone | Shows the task board. `health` checks the setup; `metrics` shows speed. |
| `/dp-setup` | Admin | Fixes settings and changes which Claude models the team uses. |

You never call the AI agents directly. The commands start them for you.

---

## 3. Common tasks: what to type

| I want to… | Type |
|------------|------|
| Build a new feature | `/dp-deliver "users can reset their password by email"` |
| Fix a bug | `/dp-deliver "the orders page shows a 500 error when the list is empty"` |
| Build it **and** deploy to SIT | `/dp-deliver "…" --to sit` |
| Review the plan before any code is written | `/dp-plan "…"` → check the stories → `/dp-sprint` → `/dp-build` |
| Plan many ideas, then build them together | run `/dp-plan` several times → `/dp-sprint` → `/dp-build sprint-1` |
| Add missing tests to a story | `/dp-test PROJ-12` |
| Test the whole UI in a browser | `/dp-test ui PROJ-12` |
| Fix a pull request (red CI or review comments) | `/dp-pr 42` |
| Deploy a release | `/dp-release sit 1.4.0` → `/dp-release uat` → `/dp-release prd 1.4.0` |
| Undo a bad production release | `/dp-release rollback` |
| Fix production **right now** | `/dp-hotfix PROJ-99 login-crash 1.4.1` |
| Continue after an interruption | `/dp-deliver resume` |
| Spend fewer tokens | `/dp-setup models save` |

**Tip:** write the requirement as you would tell a colleague. Mention the page, the user, and the expected result.

---

## 4. What happens when you run /dp-deliver

```
/dp-deliver "add CSV export"
   │
   ├─ 1. PLAN     Writes the story + acceptance criteria. Checks the backlog for duplicates.
   │              Creates the ticket (Jira, GitHub Issues, or a local file) BEFORE any code.
   ├─ 2. SPRINT   New feature → its own sprint.  Bug → the current sprint.
   │              Critical production bug (P0/P1) → stops and tells you to use /dp-hotfix.
   ├─ 3. DESIGN   Tech Lead lists the files to change, the API shape, and which tests are needed.
   ├─ 4. CODE     .NET agent: API, database, migrations  ║  Angular agent: pages, services
   ├─ 5. TEST     Unit tests · API tests on real SQL Server · browser tests (Playwright)
   ├─ 6. REVIEW   Code quality · security · performance · every changed file has a test
   ├─ 7. MERGE    Pull request into develop, merged when all checks are green
   └─ 8. DEPLOY   (only with --to sit) creates the release and deploys to SIT
```

**When does it stop and ask you?** Only when it can't tell whether your request duplicates an existing story. Everything else is automatic.

**Where can I see what it did?**

| What | Where |
|------|-------|
| Step-by-step log of the task | `docs/tasks/<TICKET>.md` |
| Requirements and acceptance criteria | `docs/requirements/<name>.md` |
| Technical plan | `docs/plans/<name>.md` |
| Test results | `docs/qa/<name>.md` |
| Code review | the pull request description |

---

## 5. Testing

Every change is tested at four levels:

| Level | Tool | What it checks |
|-------|------|----------------|
| Angular unit tests | **Vitest** | Components and services work on their own |
| .NET unit tests | **xUnit** | Business logic works on its own |
| API tests | **xUnit + WebApplicationFactory + real SQL Server** (Docker) | Endpoints, database, validation, and security work together |
| UI tests | **Playwright** | A real browser clicks through the app like a user, and checks accessibility |

The agents run tests with `bash scripts/run-tests.sh`. It saves the full output to
`.devpilot/logs/` and shows only the failures, which saves a lot of tokens. You can use it too:

```bash
bash scripts/run-tests.sh all        # or: angular | dotnet | e2e
```

---

## 6. Releasing to SIT, UAT, and production

```
develop ──(automatic)──► DEV ──/dp-release sit──► SIT ──/dp-release uat──► UAT ──/dp-release prd──► PRODUCTION
                                                                                         ▲
                                                                          a person must approve
```

| Command | What it does |
|---------|--------------|
| `/dp-release sit 1.4.0` | Creates the release branch and deploys to SIT |
| `/dp-release uat` | Deploys the tested SIT build to UAT |
| `/dp-release prd 1.4.0` | Merges to `main`, tags `v1.4.0`, and deploys to production **after you approve** |
| `/dp-release rollback` | Goes back to the previous production version (shows the plan first) |

Version numbers: new feature → `1.4.0` → `1.5.0`. Bug fix → `1.4.0` → `1.4.1`.

<details>
<summary>One-time setup for deployments</summary>

In GitHub, add these secrets: `DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`.
Add these environments: `dev`, `sit`, `uat`, `prd`. Set required reviewers on `uat` and `prd`.
</details>

---

## 7. Safety checks (quality gates)

Code is merged only when all of these pass. The AI never skips them.

- ✅ Every acceptance criterion has a test.
- ✅ Every changed source file has a test (`scripts/test-guard.sh`).
- ✅ All tests pass, and the build is green.
- ✅ No security problems, such as SQL injection, missing permission checks, secrets in code, or vulnerable packages.
- ✅ No breaking API change without a new version.
- ✅ Code review has no blocking (🔴) issues.
- ✅ CI is green on the pull request.

If a check fails, DevPilot tries to fix it up to 3 times, then stops and explains the problem.
It never deletes or weakens a test to make it pass.

For extra safety, the installer can generate a CI workflow (`.github/workflows/devpilot-ci.yml`) and protect `develop` and `main` on GitHub, so that CI must pass before anything is merged.

---

## 8. Configuration

All settings live in **`project.config.md`** in your project root. The most important ones:

```yaml
ticket_prefix: APP            # your Jira project key
base_branch: develop          # pull requests go here
tracker:
  type: jira                  # local (no setup) | github | jira
merge_policy: auto            # auto = DevPilot merges green PRs | pr-only = a person merges
language: en                  # language for requirement and test documents (code stays English)

model_policy:
  coding_profile: auto        # auto | balanced | save  (see below)
```

**Claude models.** DevPilot picks the model for each task:

| Profile | Hard tasks | Normal tasks | Simple tasks | Use when |
|---------|-----------|--------------|--------------|----------|
| `auto` (default) | Opus | Sonnet | Haiku | You want the best result |
| `balanced` | Sonnet | Sonnet | Haiku | You want lower cost, still strong |
| `save` | Sonnet | Haiku | Haiku | You want the lowest cost |

Change it with `/dp-setup models balanced`.

**Jira setup:** run `bash scripts/devpilot-config.sh set jira_api_token=<token>` (also `jira_base_url` and `jira_email`). The token is checked right away and stored in `.devpilot/config.sh`, which is never committed.

---

## What you need

| Tool | Needed? | Why |
|------|---------|-----|
| [Claude Code](https://claude.ai/code) (terminal, desktop app, VS Code/JetBrains, or web) | **Yes** | Runs the AI team |
| `git` | **Yes** | Branches and releases |
| .NET SDK and Node.js | **Yes** | To build and test your project |
| Docker | Recommended | API tests use a real SQL Server in a container |
| [GitHub CLI](https://cli.github.com) (`gh`) | Recommended | Opens and merges pull requests from the terminal |

**Your project:** an Angular frontend and/or an ASP.NET Core backend with SQL Server.

---

## Troubleshooting

**First step for any problem:** run `/dp-status health`. It tells you what's wrong and how to fix it.

| Problem | Solution |
|---------|----------|
| Jira tickets are not created | `bash scripts/devpilot-config.sh validate`, then set a new token. Until it works, tasks are logged locally, so nothing is lost. |
| API tests fail with a Docker error | Start Docker Desktop. The tests need a real SQL Server. |
| Claude hit a usage limit in the middle of a task | Nothing is lost. Wait for the limit to reset, then run `/dp-deliver resume`. |
| A pull request has red CI | `/dp-pr <PR number>` |
| Test guard blocks a file that really needs no test | Explain why in the pull request description. Don't turn the check off. |
| `gh` is not installed | Install it and run `gh auth login`, or use Claude Code on the web. |
| Health check mentions a legacy `engines:` block | Delete that block from `project.config.md` (left over from version 4). |

---

## Upgrading from 4.x

Run `bash install.sh --update`. Old commands are removed and new ones installed. Then delete the `engines:`,
`layer_overrides:`, `layer_models:`, and `fallback:` blocks from `project.config.md`, and run `/dp-setup models auto`.

| Old (4.x) | New (5.x) |
|-----------|-----------|
| `/ceo` | `/dp-deliver` |
| `/dp-plan` | `/dp-plan` (same) |
| `/dp-autofix` and `/dp-review-fix` | `/dp-pr` |
| `/dp-rollback` | `/dp-release rollback` |
| `/dp-config` | `/dp-setup` |
| OpenCode, Antigravity, `--opencode`, `AGENTS.md` | Removed (Claude only) |

---

## For DevPilot contributors

<details>
<summary>How DevPilot is built</summary>

```
.claude/commands/   the 10 /dp-* commands
.claude/agents/     team-ba · team-lead · team-frontend (Angular) · team-dotnet (.NET) · team-qa
.devpilot/skills/   23 short playbooks the agents load only when needed (index: skills/README.md)
.devpilot/rules/    coding rules for angular, dotnet, sqlserver
.devpilot/process.md  the full delivery process: phases, gates, roles
scripts/            Jira/GitHub/local tracking, git flow, tests, CI, deploy, health check
tests/run.sh        test suite for the scripts
install.sh          installer and --update
```

**Saving tokens.** Agents read one short rules file, then load a skill only at the step that needs it.
They find the right code files through a small project index (`scripts/scope.sh`) instead of reading
the whole repository. Test output is summarized. Simple tasks run on Haiku, hard tasks on Opus.

**Rolling out to many repositories:** `bash scripts/update-org.sh <github-org> --merge` opens one update PR per repository.

**Contributing:** use [Conventional Commits](https://www.conventionalcommits.org), keep one change per commit, and run
`bash tests/run.sh` before pushing.
</details>

## License

[MIT](#license). Free to use in any project, commercial or not.
