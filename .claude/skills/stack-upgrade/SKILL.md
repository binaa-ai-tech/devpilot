---
name: stack-upgrade
description: "Upgrade the Angular, .NET, EF Core or test-framework version of a DevPilot project as one planned, reversible change: one hop at a time, official migration tooling, pipelines updated with it."
when_to_use: "When a Story or Task is a framework or SDK upgrade (Angular major, net8.0/net9.0 -> net10.0, EF Core major, xUnit v2 -> v3), or a build breaks after an SDK update."
user-invocable: false
---
# Stack Upgrade — move one version at a time, prove it, ship it alone

An upgrade is its own work item and its own PR — never folded into a feature. It changes nothing
a user can see, so its proof is: same tests, same results, on the new version — and the same
outputs for the same inputs (differential tests, below).

## Plan
- **One hop at a time.** Angular one major per step (20 → 21 → 22); majors are yearly from 22
  on. .NET goes straight to the target LTS (net8.0 or net9.0 → net10.0 is one supported hop),
  but work through every skipped version's breaking-change list before editing.
- **Frontend and backend upgrade in separate commits** (the `[FE]` / `[BE]` layer tasks), so a
  failure points at one side.
- Target LTS for .NET: **10**. .NET 8 and 9 have been out of support since 10 Nov 2026 (no
  security fixes) — treat moving off them as security work, not a nice-to-have. .NET 11 is
  STS; adopt it only for a feature you need. Preview SDKs never go to `develop`.
- List the breaking changes that apply before editing: the official migration guide per hop,
  filtered to what the project uses (ASP.NET Core, EF Core, OpenAPI, auth, containers).
  Microsoft's `dotnet/skills` plugin (`dotnet-upgrade`: `migrate-dotnet8-to-dotnet9`,
  `migrate-dotnet9-to-dotnet10`, …) holds per-hop catalogs; add it with `/plugin` if the team
  upgrades often.

## Angular
- `npx ng update @angular/core@<N> @angular/cli@<N>` — let the schematics migrate; then
  `@angular/material@<N>` and other `@angular/*` packages. Commit the schematic output separately
  from hand fixes.
- Check the Node version the new major needs and update `.nvmrc` / `engines.node` with it.
- Re-read `angular-dev` → version notes (OnPush default on 22+, Signal Forms, `@Service()`); don't
  rewrite working code to the new style inside the upgrade PR.

## .NET
- Change `<TargetFramework>` (or `Directory.Build.props`), `global.json` `sdk.version`, and every
  `Microsoft.AspNetCore.*` / `Microsoft.EntityFrameworkCore.*` / `Microsoft.Extensions.*`
  package to the matching major — together, in one commit.
- New analyzer warnings are part of the upgrade: fix them or suppress with a written reason.
- EF Core: build, then `dotnet ef migrations add UpgradeCheck` — an **empty** migration proves the
  model didn't change; delete it. A non-empty one is a finding to review.
- Swashbuckle on .NET 9+: keep what exists; the built-in OpenAPI switch is a separate change
  (`dotnet-api`), and the committed OpenAPI document must come out identical (`api-contract`).
- xUnit v2 → v3 is its own change (`dotnet-testing`).

## Differential tests — prove "nothing changed" by comparing old and new
The same tests passing is necessary; it only covers what the tests look at. A differential test
runs the **old** and the **new** implementation on the **same inputs** and diffs the outputs.

1. **Inputs** — recorded API requests (from logs / a HAR, secrets and PII scrubbed), sampled DB
   rows, or generated cases (`test-design` §5 generators).
2. **Run both** — old = the base branch / deployed tag, new = this branch; same data snapshot.
3. **Normalize what does not matter** before comparing: whitespace, property / row ordering where
   order is not part of the contract, timestamps, generated IDs and GUIDs, trace ids.
4. **Compare.** Every remaining difference is a bug or an unapproved breaking change — unless it
   is listed in `docs/tests/approved-differences.md`:

   | Difference | Reason | Approved by |
   |------------|--------|-------------|
   | `GET /orders` dates gain a `Z` suffix | .NET 10 `System.Text.Json` writes UTC explicitly | <owner>, 2026-11-17 |

   The agent proposes a row; a human approves it. An unapproved difference blocks the PR.

**Recipes**
- **Angular version upgrade** — same screens, same seeded data, old build vs new build: for each
  feature in `docs/feature-map.md` capture the rendered values (table cells, totals, labels —
  text, not pixels) and the API calls made (method, URL, body), then diff. Run it through
  `scripts/verify.sh` journeys so screenshots are kept for the differences.
- **.NET API migration** (framework, serializer, Swashbuckle → built-in OpenAPI, minimal APIs) —
  replay the recorded requests against both builds on the same database snapshot and diff status
  code + JSON body (`jq -S` to sort keys, then drop the normalized fields). The committed OpenAPI
  document is diffed the same way (`api-contract`).
- **Stored-procedure rewrite** — call the old and the new procedure with the same parameter sets
  (sampled from production-like rows plus boundaries: NULLs, empty ranges, max values) and compare
  the result sets: `SELECT … EXCEPT SELECT …` both ways returns zero rows, and row counts match.
  Same SET options on both sides (`self-heal` → SQL Server checklist).

## Pipelines and tooling
- Re-run `bash scripts/generate-ci.sh --force` — it reads the SDK, Node and `dotnet-ef` versions
  from `global.json`, the `.csproj`, `.nvmrc` / `engines` and the EF package, so CI builds on
  the new toolchain. Update Dockerfiles / `deploy/` runtime images to the same version.

## Ship-with
- [ ] One hop, one PR; FE and BE in separate commits; no feature changes mixed in.
- [ ] `bash scripts/run-tests.sh all` green with the same test count as before the upgrade.
- [ ] OpenAPI document unchanged (or the difference explained); empty EF check migration.
- [ ] Differential test run on recorded / sampled inputs; every difference fixed or listed in
      `docs/tests/approved-differences.md` with a reason and an approver.
- [ ] CI regenerated on the new toolchain and green; runtime images match the TFM.
