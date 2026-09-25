# Feature — Definition of Done

`/dp-deliver` runs every step below; this list is for reviewing its work or doing a step by hand.

## 1 · Plan (`/dp-plan`)

- [ ] Deduplicated against the tracker, including the child tasks of the closest matches
- [ ] Story under an Epic, with specific, testable acceptance criteria (`definition-of-ready.md`)
- [ ] Layer tasks created: `[BE]` `[FE]` `[DB]` `[QA]` as in scope
- [ ] Spec in `docs/requirements/<slug>.md`; plan + scoped files in `docs/plans/<slug>.md`

## 2 · Build (`/dp-build`)

- [ ] Branch `feature/<key>-<slug>` from the latest `develop`
- [ ] Every AC implemented; follows `.devpilot/rules.md` for Angular · .NET · SQL Server
- [ ] API change: OpenAPI spec committed, Angular client regenerated
- [ ] DB change: EF Core migration is backward compatible (expand → contract)
- [ ] Conventional commits ending with the tracker ref (`MSK-12` · `AB#345` · `#7`)

## 3 · Verify

- [ ] `bash scripts/run-tests.sh all` green (Vitest · xUnit + SQL Server · Playwright)
- [ ] `STRICT=1 bash scripts/test-guard.sh` passes
- [ ] QA report `docs/qa/<slug>.md`: PASS on every AC; Playwright + axe for user-facing ACs
- [ ] Review gate: no open 🔴 (`code-review`, `security-scan` on auth/input changes)

## 4 · Merge

- [ ] Version bumped from `develop` (minor) and changelog entry in `docs/changes/`
- [ ] One PR `[vX.Y.Z] …` into `develop`; CI green on the head commit; merged
- [ ] Story + tasks Done, Epic Done when all its Stories are, sprint closed when empty
- [ ] `develop` auto-deploys to **DEV**; smoke test passes

## 5 · Release (`/dp-release`)

- [ ] `sit` — `release/<version>` cut from develop → built once → **SIT** + smoke test
- [ ] `uat` — a person approves **UAT** in the pipeline → smoke test → stakeholder sign-off
- [ ] `prd` — a person approves **PRD** → smoke test on production
- [ ] Then `release-finish`: PR into `main`, tag `v<version>`, PR back into `develop`
- [ ] "Released in v<version>" noted on the shipped items
