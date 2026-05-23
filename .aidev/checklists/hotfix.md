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

- [ ] Branched from the DEPLOYED PRODUCTION TAG, not from `main`
- [ ] Named `hotfix/<KEY>-<kebab-summary>`

## Step 4 — Implement

- [ ] Minimum diff. No refactoring. No unrelated improvements.
- [ ] Regression test added (still required, even under pressure)
- [ ] `.aidev/rules.md` followed for touched code

## Step 5 — Self-review

- [ ] Diff reviewed by another human if possible
- [ ] No scope creep

## Step 6 — Test & verify

- [ ] `npm test` green
- [ ] Deployed to UAT and verified — yes, even under pressure
- [ ] If UAT is unavailable, document the risk acceptance in the ticket

## Step 7 — Deploy & close

- [ ] Deployed to prod
- [ ] Verified fix in prod
- [ ] **Merged back into `main`** (or cherry-picked) — do not let the hotfix
      diverge
- [ ] Post-incident: schedule a follow-up ticket for proper fix if this was a
      band-aid
- [ ] Post-mortem written if customer-impacting
