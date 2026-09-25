# .NET API Development — ASP.NET Core Web APIs that are safe to depend on

Load this **before adding or changing an ASP.NET Core endpoint, contract, or cross-cutting
concern.** Targets .NET 8+ (LTS). `rules/dotnet.md` holds the one-liners; this is the how.
An API is a promise: once a client depends on it, careless changes break it silently.

## Shape
- Follow the project's style — **controllers** or **minimal APIs** (route groups, `TypedResults`);
  don't introduce the other. Either way: thin endpoint → service/handler → repository (`architecture-guard`).
- Resources are nouns, verbs are HTTP: `GET /api/v1/orders`, `POST /api/v1/orders`.
- Request/response **DTOs** (records) at the boundary — never expose EF entities.
- `CancellationToken` flows from the endpoint to every async call.

## Status codes & errors
- `200/201 (+Location)/204`, `400` validation, `401/403`, `404`, `409` conflict, `422` business-rule.
- **One error shape: RFC 7807 ProblemDetails** — `AddProblemDetails()` + an `IExceptionHandler`
  for unhandled exceptions. Never leak stack traces, SQL, or type names; log them server-side
  with the trace id and return the id to the client.
- Expected failures travel as a `Result<T>` from the service and are mapped to status codes in
  one place, not with exceptions.

## Validation & security
- Validate every input at the edge (FluentValidation or data annotations / built-in validation);
  return `ValidationProblem` with per-field `errors` so the Angular form can map them.
- `[Authorize]` / `.RequireAuthorization(policy)` by default; verify **resource ownership**
  (`GET /orders/{id}` checks the caller owns order `id`).
- CORS: explicit origins per environment, never `*` with credentials. Rate-limit auth and
  expensive endpoints (`AddRateLimiter`).
- Deeper checklist: `security-scan`.

## Contract
- OpenAPI is generated from code (`AddOpenApi()` / the project's generator) and is a
  **deliverable** — see `api-contract` for committing it and generating the Angular client.
- **Additive only** inside a version (new optional fields, new endpoints). A rename, removal,
  type change, or tighter validation is **breaking** → new version (`Asp.Versioning`) or a new
  field with the old one deprecated.
- Lists are **paginated** (`page`/`pageSize` capped, or keyset) and return a total or next cursor.
- Unsafe operations clients may retry (payments, submissions) accept an idempotency key.

## Operability (ships with the endpoint)
- Structured logging via `ILogger<T>` with message templates (`"Order {OrderId} created"`), no
  string interpolation, **no secrets or PII**. Log failures with context, once, at the boundary.
- Tracing/metrics via OpenTelemetry where the project has it; health checks (`MapHealthChecks`)
  still pass. Outbound `HttpClient` via `IHttpClientFactory` with timeouts + resilience
  (`AddStandardResilienceHandler`) — no unbounded waits.

## Ship-with
- [ ] DTOs + validation + auth + ownership check on every new endpoint.
- [ ] ProblemDetails for every error path; correct status codes.
- [ ] OpenAPI updated and committed; no unversioned breaking change (`api-contract`).
- [ ] Integration test per endpoint (`dotnet-testing`), verified with `bash scripts/run-tests.sh dotnet`.
