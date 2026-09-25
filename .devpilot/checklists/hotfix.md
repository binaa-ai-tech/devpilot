# Hotfix — Definition of Done

> Production-critical (P0/P1) only. Expedited — no shortcuts on safety. Run with `/dp-hotfix`.

## 1 · Triage

- [ ] Bug in the tracker, P0/P1, incident channel/thread linked
- [ ] Impact confirmed: which users, how many, what data
- [ ] Decision made: hotfix, or roll back (`/dp-release rollback`) — prefer rollback when faster and safe

## 2 · Fix

- [ ] Branch `hotfix/<key>-<slug>` from **`main`** (what is live): `bash scripts/git-flow.sh hotfix-start <KEY> <slug>`
- [ ] Minimum diff — no refactoring, no unrelated changes
- [ ] Regression test added (still required under pressure)
- [ ] Version = next patch above production: `bash scripts/version.sh next patch --ref origin/main`

## 3 · Verify

- [ ] `bash scripts/run-tests.sh all` green
- [ ] `git diff main...HEAD` reviewed — minimal; second reviewer if at all possible

## 4 · Ship

- [ ] Push the branch → pipeline builds once → **SIT** + smoke test
- [ ] A person approves **PRD** → smoke test → fix verified on production
- [ ] Then `bash scripts/git-flow.sh hotfix-finish <version>`: PR into `main`, tag, PR back into `develop`
- [ ] Bug Done in the tracker

## 5 · Learn

- [ ] Blameless postmortem in `docs/postmortems/<key>-<slug>.md` if customers were affected
- [ ] Action items and any proper follow-up fix planned via `/dp-plan`
