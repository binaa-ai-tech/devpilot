# Changelog

All notable changes to DevPilot. Versions follow [SemVer](https://semver.org); each `## [x.y.z]`
section becomes the GitHub Release notes when the `vx.y.z` tag is pushed
(`.github/workflows/release.yml`).

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
