# Bug Fix — Definition of Done

## Step 1 — Triage

- [ ] Ticket has clear repro steps
- [ ] Environment (browser/OS/build/env) documented
- [ ] Priority assigned (P0–P3)

## Step 2 — Investigate

- [ ] Bug reproduced locally
- [ ] Root cause identified (not just symptom)
- [ ] Impact Map written — including which other areas might break

## Step 3 — Branch

- [ ] Branch named `fix/<KEY>-<slug>`
- [ ] Branched from latest **`develop`** (not main)

## Step 4 — Implement

- [ ] Failing regression test written FIRST
- [ ] Smallest possible fix applied
- [ ] No unrelated refactoring
- [ ] Root cause documented in code comment + PR
- [ ] `.devpilot/rules.md` followed

## Step 5 — Self-review

- [ ] `git diff develop...HEAD` reviewed — diff is minimal, no scope creep
- [ ] Regression test now passes
- [ ] No new BLOCKERS introduced

## Step 6 — Test & Verify

- [ ] Regression test in suite
- [ ] Full test suite green
- [ ] Manual verification using original repro steps — bug is gone
- [ ] For DB bugs: env-diff done; fix verified in SIT before UAT/PRD

## Step 7 — Deploy pipeline

- [ ] PR opened targeting **`develop`**
- [ ] Merged → **DEV** auto-deployed ✅ — verify fix on DEV
- [ ] `bash scripts/git-flow.sh release-start X.Y.Z`
- [ ] **SIT** auto-deployed ✅ — verify fix on SIT
- [ ] **UAT** approved in the pipeline (GitHub Actions / Azure Pipelines) ✅ — verify fix on UAT
- [ ] `bash scripts/git-flow.sh release-finish X.Y.Z`
- [ ] **PRD** approved in the pipeline (GitHub Actions / Azure Pipelines) ✅
- [ ] Verify fix on production
- [ ] Tracker item Done with PR link + verification note
- [ ] Changelog entry under "Fixed"
