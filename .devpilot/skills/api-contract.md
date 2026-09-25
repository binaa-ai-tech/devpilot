# API Contract — one OpenAPI spec binds the .NET API and the Angular client

Load this **when an endpoint or DTO is added or changed, or when the Angular app calls an API.**
Hand-written client models drift from the server silently; a committed, generated contract makes
drift a compile error and a breaking change a red CI check.

## The loop
1. **Server owns the contract.** The .NET API generates OpenAPI from code (`AddOpenApi()` /
   the project's generator). Generate the file at build time
   (`Microsoft.Extensions.ApiDescription.Server`) or with a small script, and **commit** it
   (e.g. `api/openapi.json`).
2. **Client is generated, never hand-written.** Generate the Angular models/services from the
   committed spec with the project's tool (`ng-openapi-gen`, `openapi-typescript`, or NSwag —
   pick one, keep it) into a dedicated folder (e.g. `src/app/api/generated/`). Generated code is
   not edited by hand and is exempt from the test guard.
3. **Both land in the same PR.** An API change without the regenerated spec + client is incomplete.

## Guarding the contract
- **Snapshot test (backend):** an integration test fetches the running app's OpenAPI document
  and compares it to the committed file. An unintended change fails the build; an intended one
  updates the file in the diff, where review sees it.
- **Breaking-change check (CI):** diff the PR's spec against the base branch's with a tool
  such as `oasdiff breaking`; a breaking change without a version bump blocks merge.
- **Compile check (frontend):** after regeneration `ng build` must pass — removed or renamed
  fields surface as type errors in the components that use them.

## What counts as breaking
Removing/renaming an endpoint, field, or enum value · changing a type or nullability · making an
optional input required · tightening validation · changing status-code semantics or auth.
**Safe:** new endpoints, new optional request fields, new response fields.
Breaking changes go to a new version (`/v2`) or a new field alongside a deprecated old one.

## Tests that use the contract
- Angular specs build HTTP fixtures from the **generated types**, so a contract change breaks
  the fixture at compile time instead of passing against a stale shape.
- Playwright API seeding (`ui-e2e-playwright`) posts the same DTO shapes.

## Ship-with
- [ ] Spec regenerated and committed; Angular client regenerated in the same PR.
- [ ] Snapshot test updated intentionally (or unchanged); breaking-change check clean or versioned.
- [ ] No hand-written duplicate of a generated model.
