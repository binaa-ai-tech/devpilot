# CI/CD — automate the path to production

Load this **when adding or changing build/test/deploy automation, or wiring a new project's
pipeline.** `release-discipline` governs the environments; this governs the pipeline that feeds them.

## Continuous integration
- **Pipeline as code**, versioned with the repo — never click-configured and undocumented.
- **Every push/PR runs the gates:** install → lint → typecheck → unit/integration tests →
  build → security & dependency scan. A red gate **blocks merge**.
- **Fast feedback** — keep the PR pipeline under ~10 min; parallelize, cache deps, run slow/e2e
  suites post-merge or nightly. A slow pipeline gets bypassed.
- **Fail fast and loud**; flaky tests are bugs — quarantine and fix, don't `retry` blindly.

## Continuous delivery
- **Build once, promote the same artifact** through DEV→SIT→UAT→PRD — never rebuild per env.
  Configuration is injected per environment, not baked in (see `secrets-management`).
- **Deploys are automated, repeatable, and reversible** — one command/trigger, with a tested
  rollback path (see `release-discipline`, `feature-flags`).
- **Idempotent & immutable** — re-running a deploy is safe; artifacts are versioned and never mutated.

## Ship-with
- [ ] Change keeps the pipeline green; new code is behind the same gates (test, lint, scan).
- [ ] No secrets in pipeline config; credentials come from the CI secret store.
- [ ] Deploy/rollback path documented; same artifact promoted across environments.
