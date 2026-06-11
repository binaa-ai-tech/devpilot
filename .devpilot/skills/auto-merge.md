# Auto-Merge — the gates a robot must pass before merging

Load when merging a PR autonomously (`merge_policy: auto`) or running
`/dp-autofix`. Autonomy is earned per-merge by passing every gate — a robot
that merges on "probably fine" is a liability, not a teammate.

## The gate ladder — all green, in order
1. **Build + lint + typecheck** for every touched stack.
2. **Full test suite + test guard** — the suite is green AND
   `STRICT=1 bash scripts/test-guard.sh` passes (`test-guard.md`): every changed
   source file has a covering test or a justified exemption in the PR body.
   A green suite with no test for the new behavior fails this gate.
3. **Dependency audit** — `bash scripts/audit.sh`; no new high/critical CVEs.
4. **Review gate** — no open 🔴 (`code-review.md`); `security-scan.md` applied
   to any auth/input diff.
5. **QA verdict** — PASS on every acceptance criterion (`docs/qa/<slug>.md`).
6. **CI green on the PR head commit** — not on an older push. Update/rebase the
   branch first if base moved.

## Bounded auto-fix loop
On a red gate: diagnose from the full log, apply `self-heal.md` (3 attempts per
failure), commit `fix(ci): <what>`, push, re-run the ladder from gate 1.
**Maximum 3 push-fix cycles per PR** — then stop and escalate with the
self-heal template (diagnosis, attempts, exact failing command). Never loop
forever; never burn a fourth cycle "just in case".

## Never auto-merge when
- `merge_policy: pr-only`, or the target is `main`/a release branch — the PRD
  path always gets a human (`release-discipline.md`).
- The diff contains DB migrations not vetted against `data-migration-safety.md`,
  or touches secrets/auth configuration.
- A gate went green because a test was skipped, weakened, or an error was
  suppressed — that's a hard stop, not a pass (`self-heal.md` hard rules).
- The branch has conflicts needing semantic resolution beyond a clean rebase.

## Merge mechanics
- Squash-merge with a conventional title; body links the ticket + QA report.
- Re-run the ladder after any rebase — green-before-rebase proves nothing.
- After merge: delete the branch, move the Stories to Done, post the single
  DONE comment (`core-rules.md` #11).
