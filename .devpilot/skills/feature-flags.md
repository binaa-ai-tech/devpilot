# Feature Flags — decouple deploy from release

Load this **before shipping a risky, large, or incrementally-built feature**, or anything that
needs a kill switch or gradual rollout. Deploying code and releasing a feature become separate, safer events.

## When to flag
- Big/multi-PR features merged dark before they're complete.
- Risky changes that need a **canary** (1% → 10% → 100%) and an instant **kill switch**.
- A/B experiments or per-tenant/per-plan entitlements.

## Discipline
- **Default off.** New behavior is opt-in until proven; the off path is the current behavior.
- **Test both states** — flag-on and flag-off must each be correct and tested (see `test-strategy`).
- **One flag, one decision**, checked at a single seam — don't scatter the same flag across the codebase.
- **Kill switch is independent** of a deploy — turning a feature off must not require a release.
- **Flags are temporary debt.** Give each an owner and a removal date; **delete stale flags**
  once fully rolled out (see `tech-debt`). Long-lived config flags are the exception, and are documented.

## Rollout & guardrails
- Watch SLOs/error rate during ramp (see `reliability-slo`); roll back the flag, not the deploy, on regression.
- Never gate security/authorization decisions on a client-side flag.

## Ship-with
- [ ] New behavior behind a default-off flag with an owner + removal ticket.
- [ ] Both flag states tested; rollout/kill-switch path documented.
- [ ] Stale flags from completed rollouts removed.
