# devpilot Skills — the team's operating manual

Each skill is a short, principle-driven playbook. Agents read `core-rules.md`
plus the skills relevant to their phase; heavier skills are loaded on demand.

## Always (every agent)
| Skill | Purpose |
|-------|---------|
| `core-rules.md` | The non-negotiables, read at spawn. |
| `get-shit-done.md` | Autonomous execution — no pauses, document assumptions. |
| `compact-context.md` | Token-lean handoffs between phases. |

## Planning (BA / Team Lead)
| Skill | Purpose |
|-------|---------|
| `spec-first.md` | Every change traces to a verifiable acceptance criterion. |
| `estimation-and-slicing.md` | Cut work into thin, shippable vertical slices; size & sequence. |

## Implementation (Frontend / Backend / DB / Integration)
| Skill | Purpose |
|-------|---------|
| `architecture-guard.md` | Keep changes in the right layer / structure. |
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
| `tech-debt.md` | Take on and pay down debt deliberately; no silent debt. |
| `status-reporting.md` | Crisp, honest status at every phase boundary. |
