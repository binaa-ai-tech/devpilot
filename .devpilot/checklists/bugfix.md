# Bug Fix — Definition of Done

For P2/P3 bugs through `/dp-deliver`. P0/P1 production bugs use `/dp-hotfix` (hotfix.md).

## 1 · Triage

- [ ] One typed Bug in the tracker, with severity P2 or P3 (P0/P1 → `/dp-hotfix`)
- [ ] Deduplicated — not already reported, fixed or in progress
- [ ] Repro steps, expected vs actual, environment in `docs/bugs/<slug>.md`

## 2 · Fix

- [ ] Branch `feature/<key>-<slug>` from the latest `develop`
- [ ] Bug reproduced; root cause identified (not only the symptom) — `self-heal.md` Part 0
- [ ] Regression test written first: fails before the fix, passes after
- [ ] Smallest fix; no unrelated refactoring; root cause stated in the PR

## 3 · Verify

- [ ] `bash scripts/run-tests.sh all` green, regression test included
- [ ] `STRICT=1 bash scripts/test-guard.sh` passes
- [ ] Original repro steps no longer reproduce the bug
- [ ] DB-related: the migration or data fix verified on SIT before UAT/PRD

## 4 · Merge

- [ ] Version bumped from `develop` (patch); changelog entry (`fix`) in `docs/changes/`
- [ ] PR into `develop`, CI green, merged → Bug Done → **DEV** deployed, fix verified there

## 5 · Release

- [ ] Ships with the next release: SIT → UAT (approval) → PRD (approval), fix verified on each
