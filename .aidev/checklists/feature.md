# Feature — Definition of Done

Tick every box before marking the Jira ticket Done.

## Step 1 — Triage

- [ ] Ticket exists in Jira with type=feature
- [ ] Acceptance criteria written and specific
- [ ] Priority assigned

## Step 2 — Investigate

- [ ] Impact Map written and saved to `.aidev/impact-maps/<KEY>.md`
- [ ] Files in/out of scope defined
- [ ] Risks listed
- [ ] Rollback plan written

## Step 3 — Branch

- [ ] Branch named `feature/{prefix}-<n>-<slug>`
- [ ] Branched from latest **`develop`** (not main)
- [ ] Baseline tests pass on branch

## Step 4 — Implement

- [ ] All acceptance criteria implemented
- [ ] Code follows `.aidev/rules.md`
- [ ] Tests added alongside new code
- [ ] Commits use Conventional Commits + ticket key

## Step 5 — Self-review

- [ ] `git diff develop...HEAD` reviewed against `rules.md`
- [ ] All BLOCKERS resolved
- [ ] Warnings addressed or deferred (noted in PR)

## Step 6 — Test & Verify

- [ ] Tests green
- [ ] Lint clean
- [ ] Build clean
- [ ] Manual smoke test done

## Step 7 — Deploy pipeline

- [ ] PR opened targeting **`develop`**
- [ ] Merged → CI passes → **DEV** auto-deployed ✅
- [ ] `bash scripts/git-flow.sh release-start X.Y.Z`
- [ ] **SIT** auto-deployed ✅ — smoke test passed
- [ ] **UAT** approved in GitHub Actions ✅ — smoke test passed
- [ ] `bash scripts/git-flow.sh release-finish X.Y.Z`
- [ ] **PRD** approved in GitHub Actions ✅
- [ ] Smoke test on production passed
- [ ] Jira ticket moved to Done with PR link
- [ ] Changelog entry added
