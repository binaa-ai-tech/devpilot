<div align="center">

# DevPilot

**An AI development team for Angular + .NET projects, running inside Claude Code.**

You write what you need in one sentence. DevPilot plans it, writes the code, tests it, reviews it, and merges it.

[![Version](https://img.shields.io/badge/version-5.5.1-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Runs on](https://img.shields.io/badge/runs%20on-Claude%20Code-7c3aed.svg)](#what-you-need)
[![Stack](https://img.shields.io/badge/stack-Angular%20%7C%20.NET%20%7C%20SQL%20Server-orange.svg)](#what-you-need)
[![Trackers](https://img.shields.io/badge/trackers-Jira%20%7C%20Azure%20DevOps%20%7C%20GitHub-0052cc.svg)](#connect-jira-azure-devops-or-github)

**New in 5.5:** the team's know-how is now native Claude Code skills that load by themselves when needed,
refreshed with the latest official Angular and .NET guidance. [What changed →](CHANGELOG.md)

</div>

---

## In 30 seconds

```bash
/dp-deliver "add a CSV export button to the orders page"
```

That one command does what a full team does:

1. **Plans**: writes the user story and acceptance criteria, and checks your tracker (Jira, Azure DevOps or GitHub Issues), including existing child tasks, so nothing is created twice.
2. **Builds**: a .NET developer agent writes the API and database changes; an Angular developer agent writes the UI.
3. **Tests**: writes and runs unit tests, API tests on a real SQL Server, and browser (UI) tests.
4. **Reviews**: checks code quality, security, performance, and missing tests.
5. **Versions and merges**: bumps the version (`1.4.0` → `1.5.0`), opens a pull request into `develop`, and merges it once every check is green.
6. **Closes**: marks the tickets Done and closes the Epic and the sprint once they're finished, then switches you back to `develop`.

Works with **GitHub or Azure Repos**, and with **Jira, Azure DevOps Boards, GitHub Issues, or no tracker at all**.
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
8. [Configuration](#8-configuration) · [Connect Jira, Azure DevOps or GitHub](#connect-jira-azure-devops-or-github)
9. [What the team knows (skills)](#9-what-the-team-knows-skills)
10. [What you need](#what-you-need)
11. [Troubleshooting](#troubleshooting)
12. [Upgrading](#upgrading) · [Changelog](CHANGELOG.md)

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
| `/dp-setup` | Admin | Fixes settings, connects Jira / Azure DevOps / GitHub (`tracker`), changes Claude models. |

You never call the AI agents directly. The commands start them for you.

---

## 3. Common tasks: what to type

| I want to… | Type |
|------------|------|
| Build a new feature | `/dp-deliver "users can reset their password by email"` |
| Fix a bug | `/dp-deliver "the orders page shows a 500 error when the list is empty"` |
| Build it **and** deploy to SIT | `/dp-deliver "…" --to sit` |
| Build a ticket that already exists | `/dp-deliver PROJ-12` (Jira) · `/dp-deliver ADO-345` (Azure DevOps) · `/dp-deliver GH-7` |
| Connect Jira / Azure DevOps / GitHub | `/dp-setup tracker` |
| Review the plan before any code is written | `/dp-plan "…"` → check the stories → `/dp-sprint` → `/dp-build` |
| Plan many ideas, then build them together | run `/dp-plan` several times → `/dp-sprint` → `/dp-build sprint-1` |
| Add missing tests to a story | `/dp-test PROJ-12` |
| Test the whole UI in a browser | `/dp-test ui PROJ-12` |
| Fix a pull request (red CI or review comments) | `/dp-pr 42` |
| Deploy a release | `/dp-release sit` → `/dp-release uat` → `/dp-release prd` |
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
   ├─ 0. TRACKER  Checks Jira / Azure DevOps / GitHub is connected. If not, asks once:
   │              connect it now (paste the API key) or continue without a tracker.
   ├─ 1. PLAN     Writes the story + acceptance criteria. Searches the tracker for duplicates and
   │              opens the closest matches' child tasks. Creates Epic → Story BEFORE any code,
   │              plus one task per layer: [BE] · [FE] · [DB] · [QA].
   ├─ 2. SPRINT   New feature → its own sprint.  Bug → the current sprint.
   │              Critical production bug (P0/P1) → stops and tells you to use /dp-hotfix.
   ├─ 3. DESIGN   Tech Lead lists the files to change, the API shape, and which tests are needed.
   ├─ 4. CODE     .NET agent: API, database, migrations  ║  Angular agent: pages, services
   ├─ 5. TEST     Unit tests · API tests on real SQL Server · browser tests (Playwright)
   ├─ 6. REVIEW   Code quality · security · performance · every changed file has a test
   ├─ 7. VERSION  Bumps develop's version: feature 1.4.0 → 1.5.0 · bug 1.4.0 → 1.4.1
   │              + a changelog entry for each story
   ├─ 8. MERGE    PR "[v1.5.0] Add CSV export (PROJ-12)" into develop, merged when all checks pass
   ├─ 9. CLOSE    Stories → Done · Epic → Done (when all its stories are) · sprint → closed
   │              · you're back on develop with the latest code
   └─ 10. DEPLOY  (only with --to sit) creates release/1.5.0 and deploys to SIT
```

**When does it stop and ask you?** Only twice, and only when needed: (1) the first time, if no tracker is connected, and (2) when it can't tell whether your request duplicates an existing ticket. Everything else is automatic.

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
                                                                  ▲                       ▲
                                                         a person approves       a person approves
```

The app is **built once** per release, and that exact build moves from SIT to UAT to production. What you tested is what goes live.
After production is verified, DevPilot merges the release into `main` and tags it, so the tag always matches what's running.
Set it up once per repository with `/dp-setup pipelines`.

| Command | What it does |
|---------|--------------|
| `/dp-release sit` | Creates `release/<version>` from develop and deploys to SIT |
| `/dp-release uat` | Deploys the tested SIT build to UAT |
| `/dp-release prd` | Deploys to production **after you approve**, then merges the release into `main` and back into `develop` **through pull requests** and tags `v<version>` |
| `/dp-release rollback` | Redeploys the previous version to production (shows the plan first, still needs approval) |

**Two deliveries at the same time?** CI checks that each pull request's version is newer than `develop`'s. If another delivery merged first,
`/dp-pr` bumps the version again, so two releases never share a number.

**Release notes are automatic.** Each delivery adds its own entry file under `docs/changes/`, so pull requests never conflict on `CHANGELOG.md`.
At `/dp-release prd` the entries become the version's section, and every shipped ticket gets a "Released in vX" comment.

**Database changes** ship as a package in every build: `migrations.sql` (safe to run more than once), `rollback.sql` (back to the
previous release's schema) and `migrations.txt` (what this release changes), ready for DBAs and change boards.

**Version numbers are automatic.** Every `/dp-deliver` bumps develop's version (new feature → `1.4.0` → `1.5.0`,
bug fix → `1.4.0` → `1.4.1`) in `package.json`, `.csproj` / `Directory.Build.props` and `VERSION`. `/dp-release sit`
releases whatever version develop has. You can still give one: `/dp-release sit 2.0.0`.

<details>
<summary>One-time setup for deployments (<code>/dp-setup pipelines</code>)</summary>

`/dp-setup pipelines` generates the pipelines, makes CI required on `develop` and `main`, and creates the
`dev`, `sit`, `uat` and `prd` environments with approvals on `uat` and `prd` (choose the approvers: people or groups).
Then pick **how to deploy**. DevPilot installs a ready-made script that you can edit afterwards:

| Target | Command | What it does |
|--------|---------|--------------|
| Azure App Service | `bash scripts/deploy-init.sh appservice` | Database migrations, then zip-deploy API and web; optional staging slot plus swap for zero downtime |
| IIS (Windows Server) | `bash scripts/deploy-init.sh iis` | Over SSH: stop the app pool, copy the files, start the app pool |
| Kubernetes / AKS | `bash scripts/deploy-init.sh kubernetes` | Builds images once per version, updates the deployments, and undoes a failed rollout automatically |
| Webhook | `bash scripts/deploy-init.sh hook` | Calls your `DEPLOY_HOOK` URL |

Set `API_URL` and `FRONTEND_URL` on each environment too, so every deploy is followed by a health check.
If no deploy target is set, the deploy fails with a clear message. It never pretends to succeed.

On **Azure DevOps**, these steps need a PAT with Code (Read, write & manage) and Build (Read & execute), plus project admin rights.
Without them, each step prints what to click instead.
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

For extra safety, the installer generates the CI pipeline for your git host and protects `develop` and `main`,
so CI must pass before anything is merged. On **GitHub** that's `.github/workflows/devpilot-ci.yml` plus branch protection.
On **Azure Repos** it's `azure-pipelines.yml` plus branch policies: CI required, squash merge only, and comments resolved.
If a branch has no CI policy, DevPilot refuses to auto-merge into it, because CI would be skipped.

---

## 8. Configuration

All settings live in **`project.config.md`** in your project root. The most important ones:

```yaml
ticket_prefix: APP            # your Jira project key
base_branch: develop          # pull requests go here
tracker:
  type: azure                 # local (no setup) | jira | azure | github
  when_unconfigured: ask      # ask = offer to connect, else continue without | skip = never ask
git_host: auto                # auto (from your git remote) | github | azure
merge_policy: auto            # auto = DevPilot merges green PRs | pr-only = a person merges
versioning:
  bump: auto                  # auto = every /dp-deliver bumps the version | off
language: en                  # language for requirement and test documents (code stays English)

model_policy:
  coding_profile: auto        # auto | balanced | save  (see below)
```

**Keeping API keys safe.** Tokens are stored in `.devpilot/config.sh`, which is never committed. You can keep them somewhere safer instead:

```yaml
secrets:
  provider: keychain          # file (default) | keychain (macOS Keychain / Linux keyring) | azure-keyvault
  vault: ""                   # your Key Vault name, when provider is azure-keyvault
```
Environment variables always win, which is what CI uses.

**Cost per delivery.** A Claude Code hook records the tokens used by every session, attributed to the ticket from the branch name.
`/dp-status metrics` shows tokens per ticket and model. Add your prices to see the cost too:

```yaml
pricing:
  claude-sonnet-5: "<input>/<output>"   # USD per million tokens, from your Anthropic price sheet
```

**Claude models.** DevPilot picks the model for each task:

| Profile | Hard tasks | Normal tasks | Simple tasks | Use when |
|---------|-----------|--------------|--------------|----------|
| `auto` (default) | Opus | Sonnet | Haiku | You want the best result |
| `balanced` | Sonnet | Sonnet | Haiku | You want lower cost, still strong |
| `save` | Sonnet | Haiku | Haiku | You want the lowest cost |

Change it with `/dp-setup models balanced`.

### Connect Jira, Azure DevOps, or GitHub

Run `/dp-setup tracker` and pick one. DevPilot asks for the values below, tests the connection, and saves them in
`.devpilot/config.sh`, which is **never committed**. It then runs a **live self-test** (`/dp-setup tracker test`):
it creates a test Epic, Story and sprint in your real project, moves them to Done, checks the Epic and sprint close,
and deletes them. This way permission problems show up now, not in the middle of a delivery.

| Tracker | What you need | Sprints become |
|---------|---------------|----------------|
| **Jira** | site URL, email, [API token](https://id.atlassian.com/manage-profile/security/api-tokens), project key | Jira sprints |
| **Azure DevOps** | `https://dev.azure.com/<org>`, project name, Personal Access Token (Work Items R/W · Code R/W · Build Read) | iterations |
| **GitHub Issues** | `gh auth login`, or a token | milestones |
| **None** | nothing: tickets are kept as files in `docs/tasks/` | files in `docs/sprints/` |

Prefer not to paste keys into chat? Set them as environment variables (`JIRA_API_TOKEN`, `AZDO_PAT`, `GITHUB_TOKEN`, …).
DevPilot reads those first, which also suits CI.

Your **code** can be on GitHub or Azure Repos, whichever tracker you use. DevPilot detects it from your git remote.
Azure Repos uses the same `AZDO_PAT`.

---

## 9. What the team knows (skills)

The agents follow **24 skills**: short playbooks written for Angular + ASP.NET Core + SQL Server. They are
native Claude Code skills in `.claude/skills/`, so Claude loads each one **only when it's needed**:

| When Claude… | It loads |
|--------------|----------|
| edits an Angular component, service or route | `angular-dev` (Angular 21 and 22+ rules), `accessibility` |
| writes an Angular test (`*.spec.ts`) | `angular-testing` (Vitest) |
| edits an API endpoint or `Program.cs` | `dotnet-api` (built-in OpenAPI, validation, ProblemDetails) |
| edits a migration, `DbContext` or repository | `efcore-sqlserver` (safe migrations, fast queries) |
| writes a .NET test | `dotnet-testing` (xUnit, real SQL Server) |
| writes a browser test (`e2e/**`) | `ui-e2e-playwright` |
| plans, reviews, merges or releases | `definition-of-ready`, `review-checklist`, `security-scan`, `auto-merge`, `release-ops` |
| upgrades Angular or .NET | `stack-upgrade` |

The full list is in [.claude/skills/README.md](.claude/skills/README.md). The skills don't appear in the `/` menu:
you only use the 10 `/dp-*` commands. Your team can edit a skill to match its own conventions; `--update`
replaces DevPilot's skills with the new version, so keep your own rules in a skill with a different name.

---

## What you need

| Tool | Needed? | Why |
|------|---------|-----|
| [Claude Code](https://claude.ai/code) (terminal, desktop app, VS Code/JetBrains, or web) | **Yes** | Runs the AI team |
| `git` | **Yes** | Branches and releases |
| .NET SDK and Node.js | **Yes** | To build and test your project |
| Docker | Recommended | API tests use a real SQL Server in a container |
| [GitHub CLI](https://cli.github.com) (`gh`) | If your code is on GitHub | Opens and merges pull requests from the terminal |
| Azure DevOps Personal Access Token | If you use Azure DevOps | Tickets, pull requests, and pipeline status |
| `curl` and `jq` | **Yes** | Talk to Jira / Azure DevOps / GitHub |

**Your project:** an Angular frontend and/or an ASP.NET Core backend with SQL Server.

---

## Troubleshooting

**First step for any problem:** run `/dp-status health`. It tells you what's wrong and how to fix it.

| Problem | Solution |
|---------|----------|
| Tickets are not created in Jira / Azure DevOps | `/dp-setup tracker` tests and fixes the connection. Until then, tickets are kept locally in `docs/tasks/`, so nothing is lost. |
| I don't want to use a tracker | Answer **Continue without a tracker** once, or set `tracker.when_unconfigured: skip`. |
| Azure DevOps PR is open but not merged | Auto-complete is on: it merges as soon as the branch policies pass. Check with `/dp-pr <id>`. If it says `unprotected`, run `/dp-setup pipelines`. |
| A deploy failed with "No deploy target" | Add `deploy/deploy.sh` or a `DEPLOY_HOOK` secret for that environment (`/dp-setup pipelines`). |
| Not sure the tracker is set up right | `/dp-setup tracker test` runs a full test on your real tracker and cleans up. |
| The version didn't change | `versioning.bump` is `off` in `project.config.md`, or the PR hasn't merged yet. |
| API tests fail with a Docker error | Start Docker Desktop. The tests need a real SQL Server. |
| Claude hit a usage limit in the middle of a task | Nothing is lost. Wait for the limit to reset, then run `/dp-deliver resume`. |
| A pull request has red CI | `/dp-pr <PR number>` |
| Test guard blocks a file that really needs no test | Explain why in the pull request description. Don't turn the check off. |
| `gh` is not installed | Install it and run `gh auth login`, or use Claude Code on the web. |
| Health check mentions a legacy `engines:` block | Delete that block from `project.config.md` (left over from version 4). |

---

## Upgrading

**From 5.4:** run `bash install.sh --update`. Skills move from `.devpilot/skills/*.md` to native Claude Code
skills in `.claude/skills/<name>/SKILL.md`, and `code-review` is renamed `review-checklist` so it no longer
replaces Claude Code's built-in `/code-review`. DevPilot's old copies are removed; any skill files your team
added in `.devpilot/skills/` are kept. If you customized a DevPilot skill, copy your changes into its new file.

**From 5.0:** run `bash install.sh --update`. The per-action Jira scripts are replaced by one interface,
`scripts/tracker.sh`. Your `project.config.md` keeps working; to use the new options, add `when_unconfigured`, `git_host`,
and `versioning` from the [Configuration](#8-configuration) example.

**From 4.x:** run `bash install.sh --update`. Old commands are removed and new ones installed. Then delete the `engines:`,
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
.claude/skills/    24 native Claude Code skills: stack skills load on matching files,
                    the rest when a command or agent needs them (index: .claude/skills/README.md)
.devpilot/rules/    coding rules for angular, dotnet, sqlserver
.devpilot/process.md  the full delivery process: phases, gates, roles
scripts/            tracker.sh (+ jira.sh · azdo.sh · github.sh) · open-pr.sh · version.sh · close-delivery.sh
                    · git flow · tests · CI · deploy · health check
tests/run.sh        test suite for the scripts · tests/e2e.sh end-to-end delivery simulation
install.sh          installer and --update
CHANGELOG.md        release notes; pushing a tag vX.Y.Z publishes that section as a GitHub Release
```

**Saving tokens.** Only each skill's one-line description stays in context; its body loads when needed.
Agents preload one short rules skill (`core-rules`); Claude loads `angular-dev` when it edits a component,
`efcore-sqlserver` when it edits a migration, and so on.
They find the right code files through a small project index (`scripts/scope.sh`) instead of reading
the whole repository. Test output is summarized. Simple tasks run on Haiku, hard tasks on Opus.

**Rolling out to many repositories:** `bash scripts/update-org.sh <github-org> --merge`, or
`AZDO_PAT=… bash scripts/update-org.sh https://dev.azure.com/<org>[/<project>] --merge`. It opens one update PR per repository, into `develop`.

**Real-app check:** `tests/real-app.sh` creates a real Angular + .NET + EF Core app, installs DevPilot and runs the generated build and tests.
It runs weekly in CI (`.github/workflows/real-app.yml`).

**Contributing:** use [Conventional Commits](https://www.conventionalcommits.org), keep one change per commit, and run
`bash tests/run.sh` and `bash tests/e2e.sh` before pushing. Every change goes to `main` through a pull request.

**Releasing DevPilot:** bump `VERSION` and the README badge, add the version's section to `CHANGELOG.md`, merge,
then push the tag (`git tag v5.5.0 && git push origin v5.5.0`), or run the `release` workflow by hand on `main`
(Actions → release → Run workflow), which tags `v<VERSION>` itself. Either way it publishes the GitHub Release.
</details>

## License

[MIT](LICENSE). Free to use in any project, commercial or not.
