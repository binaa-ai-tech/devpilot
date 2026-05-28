# Skill: Release Discipline

How the team ships safely through DEV → SIT → UAT → PRD. Speed comes from a
repeatable, reversible process — not from skipping steps.

## Versioning (SemVer)
- **PATCH** (1.0.0 → 1.0.1) — bug fixes, no behavior change.
- **MINOR** (1.0.0 → 1.1.0) — new backward-compatible feature.
- **MAJOR** (1.0.0 → 2.0.0) — breaking change. Call it out loudly.
- Tag from the deployed state; find the latest: `git tag --sort=-version:refname | head -1`.

## Changelog
- Every user-facing change adds an entry (see `.devpilot/templates/changelog-entry.md`):
  what changed, why, and any migration/action required.

## Promotion gates (never skip an environment)
1. **DEV** — auto-deploys from the base branch after CI. Smoke test here first.
2. **SIT** (`/binaa-sit <version>`) — cut release branch; QA verifies.
3. **UAT** (`/binaa-uat`) — stakeholder sign-off.
4. **PRD** (`/binaa-prd <version>`) — production PR; **requires human review**.

## Before promoting to production
- [ ] All migrations are idempotent and ordered (dev → UAT → prod, no skips).
- [ ] Backward compatible, or a documented migration/cutover plan exists.
- [ ] A **rollback plan** is written (revert tag / down-migration / feature flag).
- [ ] Changelog + version bumped.

## Rules
- Production never auto-merges — a human approves the PRD PR.
- One release = one tag = one changelog section. No silent prod changes.
- Hotfixes branch from the deployed tag, not the base branch (see `.devpilot/rules.md`).
