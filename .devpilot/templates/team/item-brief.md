# Implementation Brief — build this Story from the tracker alone

> This description is self-contained: any Claude session or teammate can
> implement it from the tracker (Jira, Azure DevOps or GitHub) without the originating chat. Everything needed is below
> or linked in the repo.

## How to implement
- Repo: `<git-remote-url>` · Base branch: `<base_branch>` · Work branch: `feature/<KEY>-<slug>`
- Run it: `/dp-build` (or `/dp-deliver <KEY>`) in Claude Code. The model tier is picked per task by complexity.
- Apply skills: `core-rules` (trace every change to an AC) → layer skills as needed
  (Angular: `angular-dev`, `angular-testing`, `accessibility`; .NET: `dotnet-api`, `efcore-sqlserver`,
  `dotnet-testing`; both: `api-contract`, `security-scan`, `performance`, `architecture-guard`)
  → `ui-e2e-playwright` for user-facing ACs → `definition-of-done` before handoff.
- Full spec in repo (authoritative): `docs/requirements/<slug>.md`, domain model `docs/domain-models/<slug>.md`.

## User Story
<user story>

## Acceptance Criteria (all — implement and test each)
<full AC list>

## Scope
Layers: <frontend / backend / DB / integration>
Key files / components: <from the plan, if known>

## Technical notes
<API contracts, data/schema changes, edge cases, dependencies on other Stories>

## Definition of Done
- All acceptance criteria implemented and covered by tests (happy path + one edge/error each).
- Build + tests green; no `any`/dead code/secrets; in-scope files only.
- Review gate passed (`code-review`, `security-scan` on auth/input). See `.devpilot/skills/definition-of-done.md`.

## Tracking
- Epic: `<EPIC_KEY>` · Sprint: `<sprint or "unscheduled">` · Status: `<To Do / ready / needs grooming>`
