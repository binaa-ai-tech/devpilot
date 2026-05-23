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

- [ ] Branch named `bug/<KEY>-<kebab-summary>`

## Step 4 — Implement

- [ ] Failing regression test written FIRST
- [ ] Smallest possible fix applied
- [ ] No unrelated refactoring
- [ ] Root cause documented in code comment + PR
- [ ] `.aidev/rules.md` followed

## Step 5 — Self-review

- [ ] Diff is minimal — no scope creep
- [ ] Regression test now passes
- [ ] No new BLOCKERS introduced

## Step 6 — Test & verify

- [ ] Regression test in suite
- [ ] Full test suite green
- [ ] Manual verification using original repro steps — bug is gone
- [ ] For DB bugs: env-diff diagnosis done; fix verified in UAT before prod

## Step 7 — Deploy & close

- [ ] PR includes root cause in description
- [ ] Changelog entry under "Fixed"
- [ ] Deployed and verified in each environment
- [ ] Ticket Done with PR link + verification note
