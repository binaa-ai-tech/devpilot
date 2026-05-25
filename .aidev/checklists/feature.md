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

- [ ] Branch named `feature/<KEY>-<slug>`
- [ ] Branched from latest **`develop`** (not main)
- [ ] Baseline tests pass on branch

## Step 4 — Implement

- [ ] All acceptance criteria implemented
- [ ] Code follows `.aidev/rules.md` (no `any`, takeUntilDestroyed, OnPush, signals, etc.)
- [ ] Tests added alongside new code
- [ ] Commits use Conventional Commits + ticket key

## Step 5 — Self-review

- [ ] `git diff develop...HEAD` reviewed against `rules.md`
- [ ] All BLOCKERS resolved
- [ ] Warnings addressed or deferred (noted in PR)

## Step 6 — Test & Verify

- [ ] `npm test` green
- [ ] `npm run lint` clean
- [ ] `dotnet build apps/api -c Release` clean
- [ ] Arabic/RTL tested (if UI changes)

## Step 7 — Deploy pipeline

- [ ] PR opened targeting **`develop`**
- [ ] PR merged → CI passes → **DEV** auto-deployed ✅
- [ ] `bash scripts/git-flow.sh release-start X.Y.Z`
- [ ] Release branch pushed → CI passes → **SIT** auto-deployed ✅
- [ ] Smoke test on SIT passed
- [ ] **UAT** approved in GitHub Actions ✅ (manual gate)
- [ ] Smoke test on UAT passed
- [ ] `bash scripts/git-flow.sh release-finish X.Y.Z` (tags vX.Y.Z, merges → main + develop)
- [ ] **PRD** approved in GitHub Actions ✅ (manual gate)
- [ ] Smoke test on production passed
- [ ] Jira ticket moved to Done with PR link
- [ ] Changelog entry added
