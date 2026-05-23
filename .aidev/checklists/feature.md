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

- [ ] Branch named `feature/<KEY>-<kebab-summary>`
- [ ] Branched from latest `main`
- [ ] Baseline `npm test` passes on branch

## Step 4 — Implement

- [ ] All acceptance criteria implemented
- [ ] Code follows `.aidev/rules.md` (no `any`, takeUntilDestroyed, OnPush, etc.)
- [ ] Tests added alongside new code
- [ ] Commits use Conventional Commits + ticket key

## Step 5 — Self-review

- [ ] Self-review prompt run on diff
- [ ] All BLOCKERS resolved
- [ ] Suggestions addressed or deferred (noted in PR)

## Step 6 — Test & verify

- [ ] `npm test` green
- [ ] `npm run lint` clean
- [ ] `npm run build` clean
- [ ] Manual smoke test done in dev
- [ ] DB changes (if any) verified across dev → UAT

## Step 7 — Deploy & close

- [ ] PR opened with full description from template
- [ ] Changelog entry added
- [ ] Reviewer approved
- [ ] Merged
- [ ] Deployed to UAT, then prod
- [ ] Ticket moved to Done with PR link
