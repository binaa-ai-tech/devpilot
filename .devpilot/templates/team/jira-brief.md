# Implementation Brief — build this Story from Jira alone

> This description is self-contained: any session, opencode, or other AI tool can
> implement it from Jira without the originating chat. Everything needed is below
> or linked in the repo.

## How to implement (any AI tool)
- Repo: `<git-remote-url>` · Base branch: `<base_branch>` · Work branch: `feature/<KEY>-<slug>`
- Engine: pick per `engines.coding` (Claude or opencode/Copilot). Model balances power vs token by complexity.
- Apply skills: `spec-first` (trace every change to an AC) → layer skills as needed
  (`api-design`, `data-migration-safety`, `accessibility`, `security-scan`, `performance-review`,
  `architecture-guard`) → `definition-of-done` before handoff.
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
