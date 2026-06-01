# API Design — contracts other code depends on

Load this **before adding or changing an API endpoint / contract** (backend / integration).
An API is a promise. Once a client depends on it, changing it carelessly breaks them silently.

## Contract first
- Design the request/response shape before the implementation. Name resources as **nouns**,
  use HTTP verbs for actions (`GET /orders`, `POST /orders`, not `GET /getOrders`).
- Right status codes: `200/201/204`, `400` (validation), `401/403` (authz), `404`, `409` (conflict),
  `422`, `5xx` (never leak stack traces). Errors share **one consistent shape** (`code`, `message`, `details`).
- **Validate every input at the boundary**; never trust the client. Pair with `security-scan`.
- Paginate list endpoints; don't return unbounded collections. Filter/sort via documented query params.

## Don't break consumers
- **Additive only** within a version: new optional fields, new endpoints. Safe.
- **Breaking** (remove/rename a field, change a type, tighten validation, change status semantics)
  → **new version** (`/v2`) or a new field, with the old one deprecated, not deleted.
- Treat response fields as a contract: removing one is breaking even if "nobody uses it".

## Ship-with
- [ ] Documented contract (OpenAPI / typed DTOs) — the contract is a deliverable, not an afterthought.
- [ ] Idempotency for unsafe retried operations (e.g. payment POSTs).
- [ ] Backward-compatible DB changes underneath it (see `data-migration-safety`).
- [ ] A contract/integration test that fails if the shape changes (see `test-strategy`).
