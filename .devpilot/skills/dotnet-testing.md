# .NET Testing — xUnit unit tests + real-HTTP, real-database integration tests

Load this **when writing or fixing .NET tests.** Default stack: **xUnit**, **NSubstitute** (or the
repo's existing mock library), `WebApplicationFactory<Program>`, **Testcontainers.MsSql**, and
**Respawn**. Assertions: xUnit `Assert` or Shouldly — match the repo; don't add a second library.

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
- [ ] Suite green via `run-tests.sh`; no `Thread.Sleep`, no order dependence.
