---
name: dotnet-testing
description: "xUnit unit tests and WebApplicationFactory integration tests on real SQL Server (Testcontainers + Respawn); assertion quality and test anti-patterns."
when_to_use: "When writing or fixing .NET tests."
paths:
  - "**/*Tests/**/*.cs"
  - "**/*.Tests.csproj"
  - "**/*Tests.csproj"
user-invocable: false
---
# .NET Testing — xUnit unit tests + real-HTTP, real-database integration tests

Load this **when writing or fixing .NET tests.** Default stack: **xUnit**, **NSubstitute** (or the
repo's existing mock library), `WebApplicationFactory<Program>`, **Testcontainers.MsSql**, and
**Respawn**. Assertions: xUnit `Assert` or Shouldly — match the repo; don't add a second library.
**xUnit version:** match the repo. New test projects may use `xunit.v3` (tests are an `Exe`,
`IAsyncLifetime` returns `ValueTask`, pass `TestContext.Current.CancellationToken` — analyzer
xUnit1051). Don't migrate v2 → v3 inside a feature; that is its own change.

## What to test where
| Code | Test | How |
|------|------|-----|
| Services / handlers / domain logic | Unit | Mock repositories + external clients; no DB, no HTTP |
| Validators | Unit | Valid case + each rule's failing case |
| Endpoints (routing, auth, validation, status codes, JSON shape) | Integration | `WebApplicationFactory` + `HttpClient` |
| Repositories / EF queries / migrations | Integration | Real SQL Server in a container |
| Full UI journeys | E2E | `ui-e2e-playwright` |

## Unit tests
- Name as behavior: `CreateOrder_returns_conflict_when_sku_is_out_of_stock`.
- Arrange → Act → Assert, one behavior per test; `[Theory]` + `[InlineData]` for boundaries.
- Assert on returned values and observable calls (`repo.Received(1).AddAsync(...)`), not privates.

## Tests that lie — never ship these
- **No assertion**, or one that can't fail (`Assert.True(true)`, comparing a value with itself,
  `Assert.NotNull` alone on a result that has fields to check). Assert the exact expected value;
  `actual != oldValue` accepts every wrong answer.
- **Un-awaited async assertion** (`Assert.ThrowsAsync(...)` without `await`) — always passes.
- **Swallowed exceptions** (`try { … } catch { }`) or `Assert.Fail` in a catch — use
  `Assert.Throws` / `ThrowsAsync` on the exact exception type.
- **Time, randomness, environment:** no `Thread.Sleep` / `Task.Delay` for synchronization, no
  `DateTime.Now` / `UtcNow` in code under test (inject `TimeProvider`, use `FakeTimeProvider`),
  no unseeded `Random`, no machine paths.
- **Shared mutable state:** no `static` fields written by tests; each test arranges its own data.
- Dereferencing a result before the assertion that proves it non-null; commented-out asserts;
  a class that calls every public member without checking outcomes (coverage padding).

## Integration tests (the part that catches real bugs)
- **One SQL Server container per test run** (`MsSqlBuilder` in an `IAsyncLifetime` fixture shared
  via `ICollectionFixture`), migrations applied once at start. **Never the EF InMemory provider**
  — it has no SQL, no constraints, no transactions, and hides real defects.
- `WebApplicationFactory<Program>` with `ConfigureTestServices` to point the `DbContext` at the
  container and replace only **external** services (payment, email) with fakes.
- **Reset state between tests** with Respawn (`ResetAsync`) — tests never depend on order or on
  rows another test left behind. Seed each test's data in its Arrange.
- **Auth:** register a test auth handler (`AddAuthentication("Test")`) that issues claims from a
  header, so tests cover 401 / 403 / the owner-only path without a real identity provider.
- Assert the **contract**: status code, ProblemDetails shape on errors, and the JSON body
  (deserialize to the DTO). One test per endpoint per AC plus one 4xx path.
- Needs Docker. If Docker is unavailable, report it as a blocker — don't silently swap in InMemory.

## Token-lean runs
- Iterate narrowly: `dotnet test --filter "FullyQualifiedName~OrdersEndpoint"`.
- Full suite via `bash scripts/run-tests.sh dotnet` — short summary + failures only.
- Build once, then `dotnet test --no-build` for re-runs.

## Ship-with
- [ ] Unit test per new service/handler method: happy path + one failure branch.
- [ ] Integration test per new endpoint: success, validation 400, auth 401/403 where relevant.
- [ ] Real SQL Server via Testcontainers; Respawn between tests; no InMemory provider.
- [ ] Suite green via `run-tests.sh`; no `Thread.Sleep`, no order dependence, no test from
      "Tests that lie".

_Anti-pattern list adapted from Microsoft's `test-anti-patterns` skill (dotnet/skills, MIT)._
