# Cost Awareness (FinOps) — cost is a design constraint

Load this **before designing infrastructure, data storage, compute-heavy features, or
third-party / paid-API usage.** Cost is an engineering property like latency — cheapest to get
right at design time, painful to retrofit after a bill spike.

## Estimate before you build
- Sketch the **cost shape** of a design: what scales with traffic, data, or time?
  A choice that's free at 100 users can be ruinous at 100k.
- Watch the usual culprits: **egress/bandwidth**, storage tier & **retention**, always-on compute,
  per-call paid APIs, and chatty cross-service/cross-region traffic.

## Design for cost
- **Right-size & elastic** — autoscale to load; prefer serverless/managed for spiky or low-volume
  work instead of an idle always-on box.
- **Cache and batch** — cut repeated computation and repeated paid-API calls; a cache hit is the
  cheapest request. Beware **N+1 external calls** (pair with `performance-review`).
- **Store less, tier it, expire it** — lifecycle/retention policies; delete what you don't need
  (also a privacy win — see `data-privacy`).
- **Fail cheap** — bounded retries (see `reliability-slo`); a retry storm is a cost incident.

## Make it visible
- **Tag/label resources** for cost attribution; set **budgets and alerts** so spend is observed,
  not discovered on the invoice (see `observability`).

## Ship-with
- [ ] Rough cost-at-scale considered; no unbounded egress/storage/compute growth.
- [ ] Repeated compute/paid-API calls cached or batched; retries bounded.
- [ ] Resources tagged; a budget/alert exists for new significant spend.
