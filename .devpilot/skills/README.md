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
| `test-strategy.md` | What to test and how (the test pyramid). |
| `observability.md` | Logging, metrics, and error handling ship with the feature. |
| `performance-review.md` | Performance checklist for new code. |
| `self-heal.md` | 3-attempt recovery + limit fallback. |

## Quality & shipping (QA / Team Lead)
| Skill | Purpose |
|-------|---------|
| `code-review.md` | Structured review gate with severity tags. |
| `security-scan.md` | Security checklist over the diff. |
| `definition-of-done.md` | Per-role DoD gate before handoff. |
| `release-discipline.md` | SemVer, changelog, DEV→SIT→UAT→PRD gates, rollback. |

## Across the whole process
| Skill | Purpose |
|-------|---------|
| `debug-method.md` | Hypothesis-driven debugging (bug/issue tracks). |
| `incident-postmortem.md` | Blameless postmortem after a production incident (`/dp-hotfix`); action items → backlog. |
| `tech-debt.md` | Take on and pay down debt deliberately; no silent debt. |
| `status-reporting.md` | Crisp, honest status at every phase boundary. |
