# Changelog

All notable changes to DevPilot. Versions follow [SemVer](https://semver.org); each `## [x.y.z]`
section becomes the GitHub Release notes when the `vx.y.z` tag is pushed
(`.github/workflows/release.yml`).

## [5.9.0] — 2026-10-12

### Added
- **Project CI hooks around the .NET test step.** Files under `.devpilot/ci/` survive regeneration
  and `--update`: `before-dotnet-tests.<github|azure>.yml` and `after-dotnet-tests.<github|azure>.yml`
  (step items emitted around `tests (.NET)`) and `dotnet-tests.env` (KEY=VALUE → `env:` on that step).
  Use them for a throwaway Redis, a required-Docker flag or test filters, so a project no longer
  needs a second hand-written workflow for its .NET suite.
- **`ci.cd: auto | off`** in `project.config.md`: `off` makes `generate-ci.sh` write the CI gate only,
  on every run, for a project with no deploy target (deployed by hand). Until now that needed
  `--no-cd` each time, and a plain `--force` wrote a `devpilot-cd` that failed on every push. An
  existing CD file is reported, not deleted; `doctor.sh` no longer warns about the missing pipeline.

## [5.8.2] — 2026-10-12

### Fixed
- Generated CI runs `dotnet build` / `dotnet test` in the folder that holds the solution (`api/`,
  `src/`, …) instead of the repo root, so monorepos with the solution in a subfolder no longer fail
  with "specify a project or solution file".
- Installer detects a .NET backend from `*.slnx` solutions too (and one level deeper, e.g. `api/src/*/*.csproj`);
  a project with that layout had been installed as frontend-only, so its gate never built the API.
- Generated workflows leave the npm, pip and NuGet dependency caches out when `ci.runs_on` is a
  self-hosted label. Such a runner keeps those directories between jobs, and restoring them from
  GitHub's cache service only added time (11 to 12 minutes per job in one measurement).
  GitHub-hosted labels (`ubuntu-*`, `windows-*`, `macos-*`) keep the caches.
- On a self-hosted macOS runner the generated CI and CD skip `setup-python`, whose macOS builds
  only install under `/Users/runner`, and put the host's `python<version>` into a per-job venv
  instead. GitHub-hosted output is unchanged.

### Upgrade
`bash install.sh --update`, then regenerate the workflows to pick up the fixes:
`bash scripts/generate-ci.sh --force`.

## [5.8.1] — 2026-10-11

### Fixed
- **Local tracker keys use the project's `ticket_prefix`** (`MSK-12`) instead of always `LOCAL-12`,
  so items created locally keep the same key shape as on Jira / Azure DevOps and the sequence
  continues from existing files of that prefix. `LOCAL` remains the fallback when no prefix is set.

## [5.8.0] — 2026-10-11

### Added
- **`scripts/test-guard.exempt`**: a durable exemption list for the test guard. One repo-relative path
  or glob per line followed by a mandatory `# reason`; an entry without a reason is warned about and
  exempts nothing. The exemption and its reason are reviewed in the diff instead of living in a PR
  description. `TEST_GUARD_EXEMPT=<file>` selects another list. `install.sh --update` leaves the file
  alone. First built in a project that had to keep a patched `test-guard.sh` across updates.

### Upgrade
`bash install.sh --update`. Nothing else is required: without a `scripts/test-guard.exempt` file the
guard behaves as before. A project that patched its own `scripts/test-guard.sh` for this can take the
stock script.

## [5.7.0] — 2026-10-11

### Added
- **`ci.runs_on`** in `project.config.md`: the generated GitHub workflows take their `runs-on` from it
  (default `ubuntu-latest`), so a project can run CI on a self-hosted runner label (e.g. `binaa-mac`)
  without hand-editing generated files. Azure pipelines keep the hosted `vmImage`.
- `generate-ci.sh` runs `npm ci` in an `e2e/` folder that has its own `package.json` before installing
  Playwright browsers (monorepos with `admin/`, `portal/` and a separate `e2e/`).
- **`ci.e2e: auto | off`** in `project.config.md`: `off` leaves the Playwright journeys out of the generated
  CI (suites that need a deployed environment run from `/dp-test` or the release smoke instead).

### Fixed
- `run-tests.sh angular` runs the package's `npm test` when `angular.json` has no `test` target
  (sites tested with `node:test`) instead of failing on `ng test`.

### Upgrade
`bash install.sh --update`, then add to `project.config.md` if you use a self-hosted runner:
`ci:` / `  runs_on: <label>` and regenerate with `bash scripts/generate-ci.sh --force`.

## [5.6.0] — 2026-10-11

### Added
- **Python backend stack.** DevPilot now runs Python services (FastAPI / asyncio, LiveKit + LLM voice
  agents) with the same team flow as .NET:
  - `.devpilot/rules/python.md` — the one-line Python rules (layering, typing, async, settings, errors, logging, agents).
  - Skills `python-api` (endpoints, Pydantic schemas, typed errors, settings, agent tools) and
    `python-testing` (pytest units + `httpx` integration tests, fakes at the adapter boundary).
  - Agent `team-python` + persona `.devpilot/prompts/team/python-agent.md`; `/dp-build`, `/dp-hotfix` and
    `/dp-test` route backend work to it when `stack.backend: python`.
  - Installer detects `requirements.txt` / `pyproject.toml` → `stack.backend: python`, backend agent on.
  - `scripts/run-tests.sh python` (pytest through the project's `.venv`, failures only in context; part of `all`).
  - `scripts/generate-ci.sh` — CI: setup-python → pip install → ruff (when configured) → pytest;
    CD: the service source + requirements packaged into `out/api`. GitHub Actions and Azure Pipelines.
  - Project index shards list Python entrypoints, routers, services, adapters and tests.
  - `model-profiles.sh` / `doctor.sh` sync and check `team-python` like the other dev agents;
    `pytest`, `ruff` and `pip install` added to the shipped permission allow-list.

### Upgrade
Run `bash install.sh --update` in each project. Python projects: set `stack.backend: python` and
`agents.backend.enabled: true` in `project.config.md` (new installs get this from detection).

## [5.5.1] — 2026-09-25

### Fixed
- **Azure DevOps on macOS:** `scripts/azdo.sh` failed to load under macOS's bash 3.2, so every
  Azure Boards / Azure Repos call failed, including opening PRs. Found by the live tracker self-test.
- **Local tracker on macOS:** changing an item's status failed in the same way (`scripts/tracker.sh`).
- **Scope cache on macOS:** a scope saved in the same second as the project index was not reused
  (bash 3.2 compares file times in whole seconds), so it was worked out again instead of reused.
- Installer on macOS (bash 3.2): the settings summary printed a syntax error on the "Git host" line.
  The saved setting (`git_host: auto`) was always correct; only the summary line was affected.
- Installer printed `/dp-deliver: No such file or directory`. A comment in the generated
  `project.config.md` was run as a command and lost its text.
- All three had the same cause: a `case` statement inside `$(…)`, which bash 3.2 can't parse.
  A test now rejects that construct anywhere in DevPilot, and a new **macOS CI job** runs the full
  test suite and the end-to-end delivery under the real `/bin/bash` 3.2 on every PR.
- A new test runs the installer and fails on any shell error in its output.

### Upgrade
Already installed on a Mac? Run `bash install.sh --update` (it keeps your settings) or copy the
fixed `scripts/azdo.sh` and `scripts/tracker.sh`.

## [5.5.0] — 2026-09-25

### Added
- **Native Claude Code skills.** The 24 skills now live in `.claude/skills/<name>/SKILL.md`.
  Only each skill's one-line description stays in context. Stack skills load automatically when
  Claude edits matching files (`angular-dev` on components, `efcore-sqlserver` on migrations,
  `dotnet-testing` on test projects, `ui-e2e-playwright` on `e2e/**`). Every team agent preloads
  `core-rules`. The `/` menu still shows only the `/dp-*` commands.
- **`stack-upgrade` skill:** Angular, .NET, EF Core and xUnit upgrades, one version step per PR,
  with the pipelines regenerated.
- Generated GitHub CI/CD caches NuGet packages.

### Changed
- Skills refreshed against upstream guidance (credited in each skill):
  - **Angular:** follows the official Angular AI best practices, with notes for Angular 21 vs 22+
    (OnPush default, Signal Forms, `@Service()`, `host: {}`, `model()`, `linkedSignal()`).
  - **ASP.NET Core:** built-in OpenAPI on .NET 9+ (no Swashbuckle), `AddValidation()` for .NET 10
    minimal APIs, `TypedResults`, `sealed record` DTOs.
  - **EF Core:** measure first, sargable predicates, compiled hot queries, no lazy loading.
  - **.NET tests:** a "tests that lie" list, xUnit v3 notes, `TimeProvider`.
  - **Playwright:** a ready `webServer` config that starts the API and the Angular app.
- `code-review` skill renamed **`review-checklist`**, so it no longer replaces Claude Code's
  built-in `/code-review`.

### Upgrade
`bash install.sh --update` moves the skills from `.devpilot/skills/` to `.claude/skills/` and keeps
any skills your team added there. Copy any edits you made to a DevPilot skill into its new file.

## [5.4.2] — 2026-09-25

### Removed
- Files no command used: `new-feature.sh` (duplicate of `git-flow.sh feature-start`),
  `preflight-scan.sh`, `run-summary.sh`, `.devpilot/checklists/*`, `6-generate-tests.md`,
  `templates/ticket.md`, `.github/BRANCH_NAMING.md`. A test now fails if a script, skill, prompt
  or template is unused.

## [5.4.1] — 2026-09-25

### Fixed
- Agents gained the required `name:` field, so commands can start them by name.
- `/dp-deliver resume` now writes real checkpoints.
- The scope lock no longer blocks EF migrations.

### Added
- `.claude/settings.json` permission rules: DevPilot's routine scripts and the git / npm / dotnet
  build and test commands run without prompts. Deploy, rollback, force-push and `reset --hard`
  always ask.
- Generated pipelines read the project's own .NET SDK, Node and `dotnet-ef` versions.

## [5.4.0] — 2026-09-25

### Added
- Release and hotfix finish go through PRs into `main` and back into `develop` (merge commits),
  and the tag is placed on `main`.
- Deploy templates for Azure App Service, IIS and Kubernetes (`deploy-init.sh`), plus a database
  package in every build (`migrations.sql`, `rollback.sql`, `migrations.txt`).
- `update-org.sh` for Azure DevOps organizations, several approvers per environment, and a weekly
  real Angular + .NET app check in CI.

## [5.1.0 – 5.3.0] — 2026-09-25

### Added
- **Multi-tracker delivery:** Jira, Azure DevOps Boards, GitHub Issues or local files behind one
  `tracker.sh`. Includes a dedup check against existing items and their child tasks, and a live
  tracker self-test.
- **GitHub or Azure Repos**, with auto-complete and branch policies.
- **Versioned delivery:** every `/dp-deliver` bumps `develop`'s version and opens a
  `[vX.Y.Z]` PR. After the merge, the items, Epic and sprint are closed.
- **CD pipeline:** build once, then DEV → SIT → UAT → PRD, with approvals on UAT and PRD.
- Layer tasks ([BE] / [FE] / [DB] / [QA]), a guard against two parallel deliveries claiming the
  same version, per-item release notes, secrets in keychain or Azure Key Vault, and token cost
  per ticket.

## [5.0.0] — 2026-09-25

### Changed (breaking)
- Claude only, with 10 role-based commands: `/dp-deliver`, `/dp-plan`, `/dp-sprint`, `/dp-build`,
  `/dp-test`, `/dp-pr`, `/dp-release`, `/dp-hotfix`, `/dp-status`, `/dp-setup`.
- Focused on Angular + ASP.NET Core + SQL Server, with Playwright UI testing.
- OpenCode / Antigravity support and the `/ceo`, `/dp-config`, `/dp-autofix`, `/dp-review-fix` and
  `/dp-rollback` commands are removed. The README has the mapping from old to new commands.

## [4.0.0] — 2026-06-11

### Added
- Enterprise SDLC process contract, the test-guard gate, generated host CI with branch protection,
  a two-tier project index for low token use, and `update-org.sh` for org-wide updates.

## [2.0.0] and earlier

See the [GitHub releases](https://github.com/binaa-ai-tech/devpilot/releases).
