---
name: spec-review
description: "Elephant-Goldfish spec review: before code, the written spec must survive zero-context reviewer subagents (zoom-out, comprehension, design critic, implementation readiness); fix Blockers, then gate the Story."
when_to_use: "In /dp-plan after the requirements doc is written, in /dp-spec, and before /dp-build starts a Story whose spec was never reviewed."
user-invocable: false
---
# Spec Review — the spec must survive a reader with no memory

DevPilot's integration of Google's Elephant-Goldfish Model (vendored in `.devpilot/egm`, read
`.devpilot/egm/DEVPILOT.md` once). **Elephant** = you, with full project context, writing the
spec. **Goldfish** = fresh `egm-*` subagents that see only the page and the files you hand them.
Whatever they can't understand from the page, the implementing agent won't get right either.

## When it runs (`project.config.md → spec_review`)
| Value | Stories reviewed |
|-------|------------------|
| `auto` *(default)* | **M** and **L** Stories (`definition-of-ready` sizing), and every Story touching auth, money, PII or a public API contract |
| `always` | every Story (Bugs: only when the fix changes a contract or data shape) |
| `off` | none — the DoR "spec reviewed" item is skipped |

S Stories and ordinary Bugs skip it under `auto`: the review costs more than the risk.

## Run it autonomously (inside `/dp-plan`, `/dp-deliver`)
1. **Target** — `docs/requirements/<SLUG>.md`. **Goldfish context** — `docs/domain-models/<SLUG>.md`
   (if any), `docs/project-index.md`, and the 3–8 source files the BA scoped. Nothing else: no
   chat history, no brief that restates the spec.
2. **Artifact directory** — `docs/specs/<SLUG>/` (say `EGM artifact directory: docs/specs/<SLUG>`).
3. **Read `.devpilot/egm/skills/egm-review/SKILL.md` and follow it** with `Step: uninterrupted`.
   A requirements doc has no implementation plan, so run **stages 5–8 without pausing** (no
   human is present to answer EGM's "run stages 5–8?" offer, so proceed); stage 9 runs only when the doc carries a
   `## Implementation Plan`. Result: per-stage reports + `consolidated_review_report.md`.
4. **Remediate (the Elephant fixes, the Goldfish re-checks)** — for each 🔴 Blocker and 🟡 Major:
   - **FIX** — edit the requirements doc (ACs, scope, edge cases, data/API section), or
   - **CONTEST** — the reviewer is wrong given context it was not allowed to see; write the
     reason next to the finding. A contest must name the file or decision that settles it.
   Then re-run only the stages that raised 🔴. **At most `spec_review_rounds` rounds (default 2).**
   🟢 Nits: fix when trivial, otherwise list them.
5. **Record** — `docs/specs/<SLUG>/review.md`: rounds run, each finding → FIX / CONTEST / open,
   and the verdict **PASS** (no open 🔴) or **BLOCKED** (open 🔴 after the last round).
6. **Gate** — PASS → the DoR item "spec reviewed" is met. BLOCKED → the Story is **needs
   grooming** with the open Blockers listed; it never enters a sprint (`definition-of-ready`).
   Post the BLOCKED state on the tracker item (an exception worth a comment, `core-rules` #11).

## Run it interactively (`/dp-spec`)
The human picks the EGM preset and answers EGM's checkpoints; `egm-resolve` walks the findings
with them. Same artifact directory, same `review.md` verdict at the end.

## Rules
- Reviewers are **only** the `egm-*` agents. Never review in the main context and call it a
  Goldfish review; never paste the conversation, the brief, or your intent into a reviewer prompt.
- The review checks the **spec**, not the code. Code review stays with `review-checklist`.
- Don't weaken an AC to make a finding go away — a FIX makes the spec more precise, not vaguer.
- Keep the stages sequential (5 → 6 → 7 → 8 → 9); parallelize only reviewers within a stage.
- Commit `docs/specs/<SLUG>/` with the requirements doc: the review is part of the spec's history.
