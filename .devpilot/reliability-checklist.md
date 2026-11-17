# Reliability checklist — triggered by the diff

> Read by the review (`review-checklist`) **from the base branch**: `bash scripts/reliability.sh match`
> runs only the items whose trigger matches the diff — usually 3–10 — and each one is answered with
> evidence (a test name, a command and its output, a file:line), never "looks fine".
>
> Item format — `scripts/reliability.sh validate` checks it:
> - `## R-NN · <title>`
> - `- Paths:` comma-separated globs on changed file paths (`*` also crosses `/`) — optional
> - `- Code:` an extended regex (case-insensitive) on added or removed lines — optional
> - `- Check:` the question to answer with evidence
> - `- Origin:` `seed`, or the incident / PR that taught it (`#123`, `INC-7`)
>
> An item triggers when a changed file matches **Paths** or a changed line matches **Code**.
> New items come from misses (`.devpilot/process.md` → Review the reviewers); prune the ones that
> never trigger or never catch anything (`core-rules` → Pruning).

## R-01 · Database schema or EF Core migration
- Paths: `*/Migrations/*`, `*.sql`
- Code: `migrationBuilder\.|ALTER TABLE|CREATE TABLE|DROP (TABLE|COLUMN)|sp_rename`
- Check: Is it backward compatible with the version still running (expand → contract: no dropped or renamed column the old code reads)? Does a rollback exist — `Down()` or a rollback script — and was it run once against a copy?
- Origin: seed

## R-02 · Stored procedure change
- Paths: `*/StoredProcedures/*`, `*/Procedures/*`, `*/sp_*.sql`
- Code: `(CREATE|ALTER)( OR ALTER)? PROC`
- Check: Are the SET options it depends on (`XACT_ABORT`, `ANSI_NULLS`, `QUOTED_IDENTIFIER`, `ARITHABORT`) set inside it, and the EXECUTE / table permissions of the calling principal confirmed in every environment? (`self-heal` → Works in env A, fails in env B)
- Origin: seed

## R-03 · API contract — DTO, controller or endpoint
- Paths: `*Controller.cs`, `*/Dtos/*`, `*Dto.cs`, `*Request.cs`, `*Response.cs`, `*/Endpoints/*`, `*/schemas/*.py`
- Code: `\[Http(Get|Post|Put|Patch|Delete)|Map(Get|Post|Put|Patch|Delete)\(|@(app|router)\.(get|post|put|patch|delete)\(`
- Check: Was the OpenAPI document regenerated and the Angular client regenerated from it in this PR (`api-contract`)? Is the change additive, or versioned — no renamed / removed / newly required field for an existing caller?
- Origin: seed

## R-04 · Authorization or roles
- Code: `\[Authorize|\[AllowAnonymous|RequireAuthorization|RequireRole|Roles *=|Policy *=|canActivate|canMatch|Depends\(.*(user|auth|role)`
- Check: Is there an authorization test for every allowed role **and** at least one denied role (401 / 403), plus the owner-only path where data belongs to a user? Did any endpoint become reachable anonymously?
- Origin: seed

## R-05 · Angular route
- Paths: `*.routes.ts`, `*-routing.module.ts`
- Code: `path: *['"]|loadComponent|loadChildren|redirectTo`
- Check: Are the guards (`canActivate` / `canMatch`) still applied to every protected route, including the new and the moved ones? Does a deep link work — reloading the route directly, signed in and signed out — covered by a verify journey?
- Origin: seed

## R-06 · Logging
- Code: `_logger\.|ILogger|Log(Information|Warning|Error|Debug|Critical)\(|logger\.(info|warn|warning|error|debug|exception)\(|logging\.|console\.(log|warn|error)`
- Check: Is any personal data (name, national ID, IBAN / account number, phone, email, card) or any secret / token / connection string written to a log, directly or inside a serialized object? Structured fields, not whole DTOs.
- Origin: seed

## R-07 · Configuration or environment
- Paths: `appsettings*.json`, `*/environments/*.ts`, `.env*`, `*.config`, `azure-pipelines*.yml`, `.github/workflows/*`, `deploy/*`, `*/settings.py`
- Code: `Configuration\[|GetValue<|GetSection\(|IOptions<|process\.env|os\.environ|BaseSettings`
- Check: Is the new or renamed setting present in every environment — `.devpilot/config.sh`, pipeline variables / Key Vault for DEV, SIT, UAT and PRD — and does a missing value fail fast at start-up instead of at the first request?
- Origin: seed

## R-08 · Dates, times and time zones
- Code: `DateTime(Offset)?\.(Now|UtcNow|Today)|TimeZoneInfo|TimeProvider|new Date\(|Date\.now|datetime\.(now|utcnow|today)|zoneinfo|toLocale(Date|Time)String`
- Check: Is it tested across the UTC+4 midnight boundary (19:59 / 20:00 UTC), month-end and year-end? Is the time stored in UTC and converted only for display, with the clock injected (`TimeProvider`, fake timers) rather than read directly?
- Origin: seed

## R-09 · Money and quantity arithmetic
- Code: `\b(double|float|parseFloat|Number\()\b.*(amount|price|balance|total|fee|rate|interest|qty|quantity)|(amount|price|balance|total|fee|interest)[A-Za-z]* *[:=].*\b(double|float|parseFloat)\b|Math\.round|MidpointRounding|ROUND\(`
- Check: Are amounts `decimal` (C#, SQL `DECIMAL`), integer minor units or `Decimal` (Python) — never `float` / `double` / JS `number` arithmetic? Is the rounding rule (mode and precision) stated and tested at the half-way case?
- Origin: seed

## R-10 · Background job, retry or message handler
- Paths: `*/Jobs/*`, `*/Workers/*`, `*/Consumers/*`, `*/Handlers/*`
- Code: `BackgroundService|IHostedService|Hangfire|RecurringJob|Quartz|Polly|WaitAndRetry|AddResilienceHandler|@retry|tenacity|setInterval`
- Check: Is it idempotent — does running it twice, or again after a partial failure, give the same result (idempotency key, dedupe, upsert)? Is the retry bounded with backoff, and is a poison message parked instead of retried forever?
- Origin: seed

## R-11 · New or upgraded dependency
- Paths: `package.json`, `package-lock.json`, `*.csproj`, `Directory.Packages.props`, `requirements*.txt`, `pyproject.toml`
- Code: `PackageReference|PackageVersion|"[@a-z0-9/._-]+": *"[~^]?[0-9]`
- Check: Does `bash scripts/audit.sh` report no new high / critical advisory, is the licence acceptable, and is the package maintained? A major-version bump is its own change (`stack-upgrade`).
- Origin: seed
