---
name: security-scan
description: "Threat model at design time and a diff checklist: auth, input, secrets, PII, dependencies."
when_to_use: "When a change touches auth, money, personal data, uploads or a trust boundary, and before merge."
user-invocable: false
---
# Security — design it in, then scan the diff

Load **at design time** when a feature touches auth, money, personal data, file uploads, or a new
trust boundary, and **at diff time** before committing auth / input / data-access code and during
review. Covers threat modeling, secrets, personal data, and dependencies.

## Design time — lightweight threat model
For each trust boundary the data crosses (browser→API, API→DB, API→third party):
- **Spoofing** — who is calling? authn at the boundary. **Tampering** — validate every input.
- **Repudiation** — audit-log sensitive actions. **Information disclosure** — what leaks in
  responses, logs, URLs? **Denial of service** — rate limits, pagination, size caps.
- **Elevation of privilege** — authz + ownership on every resource.
Record each mitigation in the plan and give it a test. Deny by default; least privilege; never
roll your own crypto or auth.

## Diff checklist — all code
- [ ] No secrets, tokens, passwords, keys, or connection strings in code, config, tests, or
      fixtures (grep for `password=`, `BEGIN PRIVATE KEY`, long base64/hex). New secrets go in
      `.env.example` redacted + the secret store; code reads a *name* from config.
- [ ] No secrets or PII in logs, URLs, analytics, or error messages.
- [ ] Personal data: only fields the feature needs; encrypted in transit + at rest; retention
      and delete path exist; no real PII copied into dev/test.
- [ ] New dependency (NuGet/npm) justified, maintained, license-compatible, no known critical CVE;
      lockfile committed. `bash scripts/audit.sh` runs `npm audit --audit-level=high` and
      `dotnet list package --vulnerable --include-transitive` — no new high/critical finding.

## Backend (.NET / SQL Server)
- [ ] All SQL parameterized — EF LINQ or `FromSql` with parameters; `sp_executesql` for dynamic SQL.
- [ ] Every input validated at the API edge; ProblemDetails errors expose no stack/SQL/type names.
- [ ] Every endpoint has `[Authorize]`/policy; **ownership checked** (`/orders/{id}` belongs to caller).
- [ ] File uploads: extension allow-list, content-type check, size limit, stored outside web root.
- [ ] CORS explicit per environment, never `*` with credentials; rate limits on auth/expensive endpoints.

## Frontend (Angular)
- [ ] No `[innerHTML]` with unsanitized content; `bypassSecurityTrust*` only with a written reason.
- [ ] Tokens in httpOnly cookies or memory — never `localStorage`; never in query strings.
- [ ] No API keys, secrets, or internal URLs in the bundle or `environment.ts`.
- [ ] Client-side checks are UX only — the API enforces every rule again.

## If a secret leaks
Rotate/revoke it **first** (assume compromise), then purge history, then record it in the
postmortem (`release-ops`).

## Severity
- 🔴 **CRITICAL** (blocks PR): injection risk, auth bypass / missing ownership check, secret in
  code, XSS via unsanitized HTML, PII in logs.
- 🟡 **WARNING** (noted in review): missing input validation, permissive CORS, token in
  localStorage, unvetted dependency.
