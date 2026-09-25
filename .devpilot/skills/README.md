# devpilot Skills — the team's operating manual (Angular + .NET)

Each skill is a short, principle-driven playbook. **Token discipline: agents read
`core-rules.md` ONCE at spawn — nothing else up front.** Every other skill is loaded
**only at the step that needs it** (per `core-rules.md` rule #10). Never pre-load skill lists.

## Always (every agent) — read once
| Skill | Purpose |
|-------|---------|
| `core-rules.md` | The non-negotiables: autonomy, spec-first, scope, typing, verification, logging. |

## Planning / PM (BA / Team Lead — `/dp-refine`, `/dp-sprint`)
| Skill | Purpose |
|-------|---------|
| `definition-of-ready.md` | Entry gate — a Story enters a sprint only when clear, testable, sized, deduped. |
| `estimation-and-slicing.md` | Cut work into thin, shippable vertical slices; size & sequence. |
| `architecture-guard.md` | Keep changes in the right layer (Controller→Service→Repository; smart/dumb components). |

## Angular (Frontend Developer)
| Skill | Purpose |
|-------|---------|
| `angular-dev.md` | Standalone + signals + zoneless-safe components, HTTP services/interceptors, lazy routes, typed forms, i18n. |
| `angular-testing.md` | Vitest + TestBed specs, `HttpTestingController`, harnesses, stubbed signal services. |
| `accessibility.md` | WCAG 2.1 AA gate for UI (keyboard, labels, contrast, live regions). |

## .NET (Backend Developer)
| Skill | Purpose |
|-------|---------|
| `dotnet-api.md` | ASP.NET Core endpoints: DTOs, ProblemDetails, validation, auth + ownership, versioning, logging/resilience. |
| `efcore-sqlserver.md` | Expand/contract migrations, idempotent scripts, no-N+1 queries, indexes, pagination. |
| `dotnet-testing.md` | xUnit units + `WebApplicationFactory` integration tests on real SQL Server (Testcontainers + Respawn). |
| `api-contract.md` | Committed OpenAPI → generated Angular client; snapshot + breaking-change checks. |

## Testing & QA (QA Engineer, `/dp-test`)
| Skill | Purpose |
|-------|---------|
| `test-case-design.md` | Derive test cases from ACs (boundaries, negatives, traceability) before code. |
| `test-strategy.md` | Which pyramid layer proves what; mutation mindset. |
| `ui-e2e-playwright.md` | Full UI testing: journeys, auth once, API seeding, axe a11y, visual + mobile, traces. |
| `token-lean-testing.md` | Run suites via `scripts/run-tests.sh` — full log on disk, only failures in context. |
| `test-guard.md` | Enforcement gate — no changed source file ships without a test (`scripts/test-guard.sh`). |
| `performance.md` | Code performance checklist + k6 / web-vitals budgets. |

## Review, merge & ship (Team Lead)
| Skill | Purpose |
|-------|---------|
| `code-review.md` | Review order + severity tags; clean-code, refactoring, and PR-hygiene standards. |
| `security-scan.md` | Threat model at design time; diff checklist incl. secrets, PII, dependencies. |
| `definition-of-done.md` | Per-role DoD gate before handoff. |
| `auto-merge.md` | The gate ladder + bounded fix loop a robot must pass to merge a PR. |
| `release-ops.md` | CI/CD, SemVer, DEV→SIT→UAT→PRD gates, feature flags, SLOs, postmortems. |

## Whenever something fails
| Skill | Purpose |
|-------|---------|
| `self-heal.md` | Root-cause debugging, 3-attempt build/test recovery, limit fallback. |
