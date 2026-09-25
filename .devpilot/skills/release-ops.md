# Release & Operations — ship through DEV → SIT → UAT → PRD, then keep it running

Load **when changing the pipeline, releasing (`/dp-release`), rolling back, shipping a risky
feature, or handling an incident (`/dp-hotfix`).** Speed comes from a repeatable, reversible
process, not from skipping steps.

## CI/CD
- **Pipeline as code**, versioned with the repo. Every PR runs: restore → lint → build → unit +
  integration tests → security/dependency scan → Playwright smoke. A red gate blocks merge.
- Keep the PR pipeline under ~10 min (cache NuGet/npm, parallelize); full E2E + perf post-merge
  or nightly. Flaky tests are bugs — fix them, don't blindly retry.
- **Build once, promote the same artifact** through every environment; configuration and secrets
  are injected per environment from the CI secret store, never baked in.
- Deploys are one command, idempotent, and have a **tested rollback**.

## Versioning & changelog
- **SemVer:** PATCH = fix · MINOR = backward-compatible feature · MAJOR = breaking (call it out).
- Every user-facing change adds a changelog entry (`.devpilot/templates/changelog-entry.md`).
- One release = one tag = one changelog section.

## Promotion gates (never skip an environment)
1. **DEV** — auto-deploys from the base branch after CI; smoke test.
2. **SIT** (`/dp-release sit <version>`) — release branch cut; QA verifies.
3. **UAT** (`/dp-release uat`) — stakeholder sign-off.
4. **PRD** (`/dp-release prd <version>`) — production PR; **always a human approval**.
Before PRD: migrations idempotent and applied in order (`efcore-sqlserver`), backward compatible
or a written cutover plan, rollback plan written (revert tag / down-migration / flag off),
changelog + version bumped.

## Feature flags — decouple deploy from release
- Flag big, risky, or incrementally-built features: **default off**, one flag per decision
  checked at one seam, kill switch that needs no deploy, both states tested.
- Every flag has an owner and a removal date; delete it once fully rolled out.
- Never gate authorization on a client-side flag.

## Reliability
- Critical journeys have an **SLO** (e.g. 99.9 % success over 30 days); alert on SLO burn and
  user-facing errors, not raw CPU. Error budget spent → reliability work before features.
- Remote calls: timeouts, bounded retries with backoff + jitter, circuit breaker, graceful
  degradation. No single point of failure on a critical path.

## Incidents & postmortems
- Hotfixes branch from the **deployed tag**, minimum diff, verified on UAT, merged back.
- After any P0/P1, customer-impacting outage, data issue, or rollback, write a **blameless**
  postmortem to `docs/postmortems/<KEY>-<slug>.md`: summary · UTC timeline (detected → mitigated
  → resolved) · root cause (5 whys, via `self-heal` Part 0) · resolution · what went well/hurt ·
  action items.
- Every action item becomes a backlog Story via `/dp-plan` with an owner. A postmortem with no
  follow-up is theatre; a recurring root cause is a process failure.
