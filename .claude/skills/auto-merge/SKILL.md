---
name: auto-merge
description: "The gate ladder and bounded fix loop a robot must pass before merging a PR."
when_to_use: "When merging autonomously or running /dp-pr."
user-invocable: false
---
# Auto-Merge — the gates a robot must pass before merging

Load when merging a PR autonomously (`merge_policy: auto`) or running
`/dp-pr`. Autonomy is earned per-merge by passing every gate — a robot
that merges on "probably fine" is a liability, not a teammate.

**Autonomous, not human-gated.** Under `merge_policy: auto` the gates below are the
*entire* approval. The **QA verdict comes from the `team-qa` agent + the automated suite**,
never from asking the user to test, verify, or click approve. Do **not** open the PR and hand
it back for manual testing — pass the ladder and merge. The only stops are a **red gate the
bounded auto-fix loop can't clear** (escalate) or one of the **never-auto-merge** conditions
below. Waiting on human action when every gate is green is a defect, not caution.

## The gate ladder — all green, in order
1. **Build + lint + typecheck** for every touched stack.
2. **Full test suite + test guard** — the suite is green AND
   `STRICT=1 bash scripts/test-guard.sh` passes (`test-guard`): every changed
   source file has a covering test or a justified exemption in the PR body.
   A green suite with no test for the new behavior fails this gate.
3. **Dependency audit** — `bash scripts/audit.sh`; no new high/critical CVEs.
4. **Review gate** — no open 🔴 (`review-checklist`); `security-scan` applied
   to any auth/input diff.
5. **QA verdict** — PASS on every acceptance criterion (`docs/qa/<slug>.md`).
6. **CI green on the PR head commit** — not on an older push. Update/rebase the
   branch first if base moved.

## Bounded auto-fix loop
On a red gate: diagnose from the full log, apply `self-heal` (3 attempts per
failure), commit `fix(ci): <what>`, push, re-run the ladder from gate 1.
**Maximum 3 push-fix cycles per PR** — then stop and escalate with the
self-heal template (diagnosis, attempts, exact failing command). Never loop
forever; never burn a fourth cycle "just in case".

## Never auto-merge when
- `merge_policy: pr-only`, or the target is `main`/a release branch — the PRD
  path always gets a human (`release-ops`).
- The diff contains DB migrations not vetted against `efcore-sqlserver`,
  or touches secrets/auth configuration.
- A gate went green because a test was skipped, weakened, or an error was
  suppressed — that's a hard stop, not a pass (`self-heal` hard rules).
- The branch has conflicts needing semantic resolution beyond a clean rebase.

## Merge mechanics
- **Version first** — the PR carries exactly one bump above the base branch's version
  (`version.sh bump <level> --ref origin/<base>`; feature → minor, bug → patch). If the base
  moved to a new version, redo the bump from it before merging. Title: `[vX.Y.Z] <summary> (<refs>)`.
- Squash-merge; body links the items + QA report and ends with the
  `<!-- devpilot: keys=… sprint=… version=… -->` line `/dp-pr` reads.
- Transport by host: GitHub → `gh pr merge --squash --delete-branch` (or `--auto` while checks run;
  GitHub MCP `merge_pull_request` where `gh` is missing). Azure Repos → `azdo.sh pr-complete`
  (auto-complete: squash + delete source branch the moment branch policies pass).
- Re-run the ladder after any rebase — green-before-rebase proves nothing.
- After a **confirmed** merge only: `close-delivery.sh` — items Done with the merged comment,
  Epic Done when all children are, sprint closed when nothing is open, back on the base branch.
