---
name: dotnet-api
description: "How to build ASP.NET Core endpoints: DTOs, ProblemDetails, validation, auth + ownership, OpenAPI, versioning, logging, resilience."
when_to_use: "Before adding or changing an endpoint, contract or cross-cutting concern in the .NET API."
paths:
  - "**/Controllers/**/*.cs"
  - "**/Endpoints/**/*.cs"
  - "**/Program.cs"
  - "**/*Dto.cs"
  - "**/*Request.cs"
  - "**/*Response.cs"
user-invocable: false
---
# .NET API Development — ASP.NET Core Web APIs that are safe to depend on

Load this **before adding or changing an ASP.NET Core endpoint, contract, or cross-cutting
concern.** Targets .NET 8 and 10 (LTS), with notes where 9+/10+ differ. `rules/dotnet.md` holds the
one-liners; this is the how.
An API is a promise: once a client depends on it, careless changes break it silently.

## Shape
- Follow the project's style — **controllers** or **minimal APIs** (route groups, `TypedResults`);
  don't introduce the other. Either way: thin endpoint → service/handler → repository (`architecture-guard`).
- Resources are nouns, verbs are HTTP: `GET /api/v1/orders`, `POST /api/v1/orders`.
- Request/response **DTOs** at the boundary — never expose EF entities. `sealed record`s named
  `Create{Entity}Request` / `Update{Entity}Request` / `{Entity}Response`, with `/// <summary>` XML
  docs (they flow into the OpenAPI document). Dates are `DateTimeOffset`, enums serialize as
  strings (`JsonStringEnumConverter`), no mutable `{ get; set; }` DTOs.
- Minimal APIs: one static `{Resource}Endpoints.Map{Resource}()` per resource on a route group;
  handlers return **`TypedResults`** with an explicit `Results<Ok<T>, NotFound>` signature (a bare
  ternary of two `TypedResults` doesn't compile). POST returns `201` + `Location`.
- `CancellationToken` flows from the endpoint to every async call.

## Status codes & errors
- `200/201 (+Location)/204`, `400` validation, `401/403`, `404`, `409` conflict, `422` business-rule.
- **One error shape: RFC 7807 ProblemDetails** — `AddProblemDetails()` + an `IExceptionHandler`
  for unhandled exceptions. Never leak stack traces, SQL, or type names; log them server-side
  with the trace id and return the id to the client.
- Expected failures travel as a `Result<T>` from the service and are mapped to status codes in
  one place, not with exceptions.

## Validation & security
- Validate every input at the edge (FluentValidation or data annotations); return
  `ValidationProblem` with per-field `errors` so the Angular form can map them. Controllers validate
  annotations automatically; **minimal APIs on .NET 10+ need `builder.Services.AddValidation()`**.
- Existing APIs keep their JSON settings (stricter options break clients); new projects may use
  strict number handling, case-sensitive names and `AllowDuplicateProperties = false`.
- `[Authorize]` / `.RequireAuthorization(policy)` by default; verify **resource ownership**
  (`GET /orders/{id}` checks the caller owns order `id`).
- CORS: explicit origins per environment, never `*` with credentials. Rate-limit auth and
  expensive endpoints (`AddRateLimiter`).
- Deeper checklist: `security-scan`.

## Contract
- OpenAPI is generated from code and is a **deliverable**. On .NET 9+ use the built-in
  `Microsoft.AspNetCore.OpenApi` (`AddOpenApi()` + `MapOpenApi()`); **never add Swashbuckle to a
  .NET 9+ project** (keep it where it already exists, or on .NET 8). Endpoints carry
  `.WithName` / `.WithSummary` / `.Produces<T>` metadata. It is a deliverable — see `api-contract` for committing it and generating the Angular client.
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
- [ ] A `.http` file (or the project's equivalent) exercises the new endpoints by hand.
- [ ] Integration test per endpoint (`dotnet-testing`), verified with `bash scripts/run-tests.sh dotnet`.
