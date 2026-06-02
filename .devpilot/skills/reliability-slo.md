# Reliability & SLOs — define "good enough", then defend it

Load this **when setting reliability targets for a service, designing for failure, or planning
on-call.** `observability` gives you the signals; this turns them into targets and decisions.

## Measure what users feel
- **SLI** — a metric of user-visible health: availability, latency (p95/p99), error rate, freshness.
- **SLO** — the target for an SLI over a window (e.g. *99.9% of requests succeed in 30 days*).
  Set it from user need, not vanity; 100% is the wrong target — it forbids all change.
- **Error budget** = `1 − SLO`. Budget left → ship features. Budget burned → freeze features and
  fix reliability. This makes the speed-vs-stability trade-off **data-driven, not political**.

## Design for failure
- **Everything remote fails** — apply timeouts, bounded retries with backoff + jitter, and
  circuit breakers. No unbounded waits.
- **Degrade gracefully** — partial functionality beats a hard down (cache, fallback, queue).
- **No single point of failure** on a critical path; make critical operations idempotent.
- **Alert on symptoms** (SLO burn, user-facing errors), not causes — actionable, not noisy.

## Ship-with
- [ ] Critical user journeys have an SLI + SLO; alerting is on SLO burn, not raw CPU.
- [ ] External calls have timeouts, retry limits, and a fallback/degraded path.
- [ ] Failure modes considered; postmortem action items tracked (see `incident-postmortem`).
