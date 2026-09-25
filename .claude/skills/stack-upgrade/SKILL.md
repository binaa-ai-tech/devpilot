---
name: stack-upgrade
description: "Upgrade the Angular, .NET, EF Core or test-framework version of a DevPilot project as one planned, reversible change: one hop at a time, official migration tooling, pipelines updated with it."
when_to_use: "When a Story or Task is a framework or SDK upgrade (Angular major, net8.0 -> net10.0, EF Core major, xUnit v2 -> v3), or a build breaks after an SDK update."
user-invocable: false
---
# Stack Upgrade — move one version at a time, prove it, ship it alone

An upgrade is its own work item and its own PR — never folded into a feature. It changes nothing
a user can see, so its proof is: same tests, same results, on the new version.

## Plan
- **One hop at a time.** Angular one major per step (20 → 21 → 22); .NET one TFM per step
  (net8.0 → net9.0 → net10.0), fixing each hop's breaking changes before the next.
- **Frontend and backend upgrade in separate commits** (the `[FE]` / `[BE]` layer tasks), so a
  failure points at one side.
- Prefer LTS for .NET (8, 10). Preview SDKs never go to `develop`.
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

## Pipelines and tooling
- Re-run `bash scripts/generate-ci.sh --force` — it reads the SDK, Node and `dotnet-ef` versions
  from `global.json`, the `.csproj`, `.nvmrc` / `engines` and the EF package, so CI builds on
  the new toolchain. Update Dockerfiles / `deploy/` runtime images to the same version.

## Ship-with
- [ ] One hop, one PR; FE and BE in separate commits; no feature changes mixed in.
- [ ] `bash scripts/run-tests.sh all` green with the same test count as before the upgrade.
- [ ] OpenAPI document unchanged (or the difference explained); empty EF check migration.
- [ ] CI regenerated on the new toolchain and green; runtime images match the TFM.
