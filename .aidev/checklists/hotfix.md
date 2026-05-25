# Hotfix — Definition of Done

> Production-critical only. Expedited flow — but no shortcuts on safety.

## Step 1 — Triage

- [ ] Ticket created, type=hotfix, priority P0
- [ ] Incident channel/thread linked
- [ ] Impact scope confirmed (which users, how many, what data)

## Step 2 — Investigate

- [ ] Reproduced or root cause confirmed via logs
- [ ] Decision: hotfix vs roll-back. If roll-back is faster and safe, prefer it.
- [ ] Impact Map written (can be brief)

## Step 3 — Branch

- [ ] Branched from **`main`** (the live production code)
- [ ] Named `hotfix/<KEY>-<slug>`

```bash
bash scripts/git-flow.sh hotfix-start <ticket-number> <slug>
```

## Step 4 — Implement

- [ ] Minimum diff. No refactoring. No unrelated improvements.
- [ ] Regression test added (still required, even under pressure)
- [ ] `.aidev/rules.md` followed for touched code

## Step 5 — Self-review

- [ ] `git diff main...HEAD` reviewed — diff is minimal, no scope creep
- [ ] Reviewed by another person if possible
- [ ] No new issues introduced

## Step 6 — Test & Verify

- [ ] `npm test` + `dotnet test` green
- [ ] Manual smoke test done

## Step 7 — Deploy pipeline

```bash
bash scripts/git-flow.sh hotfix-finish X.Y.Z
# merges hotfix → main, tags vX.Y.Z, merges back → develop
```

- [ ] CI runs on `main` push — lint + test + build pass ✅
- [ ] **PRD** approved in GitHub Actions ✅ (manual gate)
- [ ] Fix verified on production
- [ ] `develop` also has the fix (git-flow.sh handles this automatically)
- [ ] Jira ticket Done
- [ ] Post-mortem written if customer-impacting
- [ ] Follow-up ticket created for proper fix if this was a band-aid
