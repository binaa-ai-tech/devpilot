# devpilot Skills — the team's operating manual (Angular + .NET)

Each skill is a short, principle-driven playbook, stored as a native Claude Code skill
(`.claude/skills/<name>/SKILL.md`). **Token discipline:** only each skill's one-line description
sits in context; the body loads when needed. `core-rules` is preloaded into every team agent
(`skills:` in its frontmatter). Stack skills carry `paths:` globs, so Claude loads them
automatically when it edits matching files (`angular-dev` on `*.component.ts`, `efcore-sqlserver`
on `Migrations/**`, …); commands and agents load the others by name at the step that needs them.
All are `user-invocable: false` — the `/` menu shows only the `/dp-*` commands.

## Always (every agent) — read once
| Skill | Purpose |
|-------|---------|
| `core-rules` | The non-negotiables: autonomy, spec-first, scope, typing, verification, logging. |

## Planning / PM (BA / Team Lead — `/dp-plan`, `/dp-sprint`)
| Skill | Purpose |
|-------|---------|
| `definition-of-ready` | Entry gate — a Story enters a sprint only when clear, testable, sized, deduped. |
| `estimation-and-slicing` | Cut work into thin, shippable vertical slices; size & sequence. |
| `architecture-guard` | Keep changes in the right layer (Controller→Service→Repository; smart/dumb components). |

## Angular (Frontend Developer)
| Skill | Purpose |
|-------|---------|
| `angular-dev` | Standalone + signals + zoneless-safe components, HTTP services/interceptors, lazy routes, typed forms, i18n. |
| `angular-testing` | Vitest + TestBed specs, `HttpTestingController`, harnesses, stubbed signal services. |
| `accessibility` | WCAG 2.1 AA gate for UI (keyboard, labels, contrast, live regions). |

## .NET (Backend Developer)
| Skill | Purpose |
|-------|---------|
| `dotnet-api` | ASP.NET Core endpoints: DTOs, ProblemDetails, validation, auth + ownership, versioning, logging/resilience. |
| `efcore-sqlserver` | Expand/contract migrations, idempotent scripts, no-N+1 queries, indexes, pagination. |
| `dotnet-testing` | xUnit units + `WebApplicationFactory` integration tests on real SQL Server (Testcontainers + Respawn). |
| `api-contract` | Committed OpenAPI → generated Angular client; snapshot + breaking-change checks. |

## Testing & QA (QA Engineer, `/dp-test`)
| Skill | Purpose |
|-------|---------|
| `test-case-design` | Derive test cases from ACs (boundaries, negatives, traceability) before code. |
| `test-strategy` | Which pyramid layer proves what; mutation mindset. |
| `ui-e2e-playwright` | Full UI testing: journeys, auth once, API seeding, axe a11y, visual + mobile, traces. |
| `token-lean-testing` | Run suites via `scripts/run-tests.sh` — full log on disk, only failures in context. |
| `test-guard` | Enforcement gate — no changed source file ships without a test (`scripts/test-guard.sh`). |
| `performance` | Code performance checklist + k6 / web-vitals budgets. |

## Maintenance
| Skill | Purpose |
|-------|---------|
| `stack-upgrade` | Angular / .NET / EF Core / xUnit version upgrades — one hop per PR, pipelines regenerated. |

## Review, merge & ship (Team Lead)
| Skill | Purpose |
|-------|---------|
| `review-checklist` | Review order + severity tags; clean-code, refactoring, and PR-hygiene standards. |
| `security-scan` | Threat model at design time; diff checklist incl. secrets, PII, dependencies. |
| `definition-of-done` | Per-role DoD gate before handoff. |
| `auto-merge` | The gate ladder + bounded fix loop a robot must pass to merge a PR. |
| `release-ops` | CI/CD, SemVer, DEV→SIT→UAT→PRD gates, feature flags, SLOs, postmortems. |

## Whenever something fails
| Skill | Purpose |
|-------|---------|
| `self-heal` | Root-cause debugging, 3-attempt build/test recovery, limit fallback. |
