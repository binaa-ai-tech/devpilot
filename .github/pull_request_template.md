## Work item

<!-- Jira: MSK-12 · Azure Boards: AB#345 (auto-links) · GitHub: #7 · local: LOCAL-3 -->
<KEY and link>

**Version:** v<X.Y.Z> <!-- /dp-deliver sets it: feature → minor, bug → patch -->

## What and why

<!-- One or two sentences: the user-visible change and the reason. -->

## Type of change

- [ ] Feature / enhancement
- [ ] Bug fix
- [ ] Hotfix (production)
- [ ] Breaking change (API contract or behaviour — say what and the migration path below)
- [ ] Refactor / tech debt
- [ ] Docs / CI / tooling

## Changes

-

## Acceptance criteria

<!-- Each AC from the Story, and the test that proves it. -->

| AC | Covered by |
|----|-----------|
| AC1 | |

## Testing

- [ ] `bash scripts/run-tests.sh all` green (Vitest · xUnit + SQL Server · Playwright)
- [ ] `STRICT=1 bash scripts/test-guard.sh` — every changed source file has a test (or a justified exemption below)
- [ ] Bug fix: a regression test fails before the fix and passes after
- [ ] UI change: Playwright journey + axe scan for the new/changed screen

## Checklist

- [ ] Follows `.devpilot/rules.md` for the touched layers (Angular · .NET · SQL Server)
- [ ] API change: OpenAPI spec committed and the Angular client regenerated; breaking changes versioned
- [ ] Database change: EF Core migration is backward compatible (expand → contract) and reviewed
- [ ] No secrets, connection strings or tokens in code or config — environment settings only
- [ ] Changelog entry in `docs/changes/` (`bash scripts/changelog.sh add <KEY> <feat|fix> "<summary>"`)
- [ ] UI in RTL languages checked (only if the app supports them)

## Breaking changes / migration

<!-- None, or what changes and how consumers migrate. -->

## Deployment notes

<!-- New settings per environment, feature flags, data backfills, ordering with other releases. None if nothing special. -->

## Screenshots

<!-- UI changes only. -->
