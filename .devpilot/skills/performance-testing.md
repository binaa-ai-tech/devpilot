# Performance Testing — prove the budget, don't guess

Load when an AC carries a performance requirement, before a major release, or
on `/dp-test perf`. `performance-review.md` checks the *code*; this verifies the
*running system* against numbers. High-performance software is a measured
budget, not an adjective.

## Budgets first
A perf test without a budget is a demo. Take budgets from the requirements;
when the spec is silent, hold these defaults and record them in the QA report:

| Surface | Budget |
|---------|--------|
| API reads | p95 < 300 ms, p99 < 1 s (in-region, at target load) |
| API writes | p95 < 800 ms |
| Error rate | < 0.1 % at target load |
| Web vitals | LCP < 2.5 s · INP < 200 ms · CLS < 0.1 |
| Throughput | sustains expected peak × 2 without the knee |

## Test types — run what the risk demands
- **Smoke** — 1 VU sanity; the script itself works. Always.
- **Load** — expected peak for 10–15 min; budgets must hold. For any hot-path change.
- **Stress** — ramp until the knee; record where and what breaks first.
- **Soak** — hours at moderate load; catches memory/connection leaks.
- **Spike** — sudden ×10; verifies recovery, not just survival.

## How
- **k6** is the default (scripted JS, CI-friendly); JMeter/Gatling/Locust are
  fine if established. Scripts live in the repo under `perf/`, versioned like code.
- Test a **prod-like environment with realistic data volume** — an empty table
  lies about every query plan. Never load-test PRD.
- Measure **percentiles, never averages**; warm up before the measured window;
  pin the dataset + duration so runs are comparable over time.
- Pair findings with `database-performance.md` (query plans, indexes) and
  `cost-awareness.md` (don't buy your way out of an N+1).

## Gate
- A budget violation on a hot path is a 🔴 **BLOCKER** in the QA report —
  attach the numbers (baseline vs. now, percentile table), not adjectives.
