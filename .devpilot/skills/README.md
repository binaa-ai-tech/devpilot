# devpilot Skills — the team's operating manual

Each skill is a short, principle-driven playbook. **Token discipline: agents read
`core-rules.md` ONCE at spawn — nothing else up front.** Every heavier skill is loaded
**only at the step that needs it** (per `core-rules.md` rule #10). Never pre-load skill lists.

## Always (every agent) — read once
| Skill | Purpose |
|-------|---------|
| `core-rules.md` | The non-negotiables. Folds in `get-shit-done` + `spec-first` essentials, so those are **not** read separately. |

## On demand only (load at point of use)
`compact-context` (before a phase handoff) · `get-shit-done`/`spec-first` (full detail, rarely needed beyond core-rules) · everything below.

## Planning / PM (BA / Team Lead — `/dp-plan`, `/dp-sprint`)
| Skill | Purpose |
|-------|---------|
| `spec-first.md` | Every change traces to a verifiable acceptance criterion. |
| `definition-of-ready.md` | Entry gate — a Story may enter a sprint only when ready (clear, testable, sized, deduped). |
| `estimation-and-slicing.md` | Cut work into thin, shippable vertical slices; size & sequence. |

## Implementation (Frontend / Backend / DB / Integration)
| Skill | Purpose |
|-------|---------|
| `architecture-guard.md` | Keep changes in the right layer / structure. |
| `api-design.md` | Contract-first endpoints; versioning; no silent breaking changes. |
| `data-migration-safety.md` | Expand/contract, reversible, online DB migrations (zero downtime). |
| `accessibility.md` | WCAG 2.1 AA gate for UI (keyboard, labels, contrast, live regions). |
| `i18n.md` | Externalize strings; locale-aware dates/numbers/currency; Unicode + RTL. |
| `clean-code.md` | Naming, small functions, readability — write for the next reader. |
| `refactoring.md` | Change structure without changing behavior; tests-first, small steps. |
| `test-strategy.md` | What to test and how (the test pyramid). |
| `performance-testing.md` | Load/stress/soak budgets — prove the running system, not just the code. |
| `observability.md` | Logging, metrics, and error handling ship with the feature. |
| `performance-review.md` | Performance checklist for new code. |
| `database-performance.md` | Indexes, query plans, N+1, pagination — make the schema fast. |
| `cost-awareness.md` | Treat cloud/API cost as a design constraint; cache, right-size, expire. |
| `feature-flags.md` | Decouple deploy from release; default-off, kill switch, clean up stale flags. |
| `self-heal.md` | 3-attempt recovery + limit fallback. |

## Security & data (design-time + diff-time)
| Skill | Purpose |
|-------|---------|
| `threat-modeling.md` | Security by design (STRIDE, trust boundaries) before building auth/data/input features. |
| `security-scan.md` | Security checklist over the diff. |
| `secrets-management.md` | Credentials never in code; env/secret manager, rotation, no secrets in logs. |
| `data-privacy.md` | Classify/minimize personal data; PII controls, retention, erasure (GDPR shape). |
| `dependency-management.md` | Own the supply chain: vet, pin/lock, scan, license, update cadence. |

## Quality & shipping (QA / Team Lead)
| Skill | Purpose |
|-------|---------|
| `test-case-design.md` | Derive test cases from ACs (boundaries, negatives, traceability) before code. |
| `test-guard.md` | **Highly recommended** enforcement gate — no changed source file ships without a test (`scripts/test-guard.sh`). |
| `e2e-testing.md` | A few critical journeys, made stable enough to gate a merge. |
| `code-review.md` | Structured review gate with severity tags. |
| `version-control.md` | Atomic commits + small, single-purpose, CI-green PRs. |
| `definition-of-done.md` | Per-role DoD gate before handoff. |
| `ci-cd.md` | Pipeline-as-code, quality gates, build-once/promote, reversible deploys. |
| `auto-merge.md` | The gate ladder + bounded fix loop a robot must pass to merge a PR. |
| `release-discipline.md` | SemVer, changelog, DEV→SIT→UAT→PRD gates, rollback. |

## Across the whole process
| Skill | Purpose |
|-------|---------|
| `debug-method.md` | Hypothesis-driven debugging (bug/issue tracks). |
| `reliability-slo.md` | SLIs/SLOs/error budgets; design for failure (timeouts, retries, degrade). |
| `incident-postmortem.md` | Blameless postmortem after a production incident (`/dp-hotfix`); action items → backlog. |
| `tech-debt.md` | Take on and pay down debt deliberately; no silent debt. |
| `documentation.md` | README/ADR/runbook authoring; docs as a deliverable, kept next to code. |
| `status-reporting.md` | Crisp, honest status at every phase boundary. |
