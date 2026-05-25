# /binaa-index — Refresh Project Index

Generate or refresh `docs/project-index.md` — the codebase map the BA agent reads first on every task.

---

## Run

```bash
bash scripts/generate-project-index.sh
```

Then commit the result:

```bash
git add docs/project-index.md
git commit -m "chore(git): refresh project index"
```

---

## When to run

| Situation | Why |
|-----------|-----|
| First install (before any `/ceo` task) | Index doesn't exist yet |
| After major refactoring (moved/renamed many files) | Index is stale |
| After adding a new app, module, or service | New files not in index |
| Before starting work on an unfamiliar area | Gives the BA agent accurate context |

---

## What it produces

`docs/project-index.md` — one line per significant source file, grouped by type:

```
## Components
  apps/web/src/app/listings/listing-card.component.ts    — class ListingCardComponent
  apps/web/src/app/listings/listing-detail.component.ts  — class ListingDetailComponent

## API Controllers / Endpoints (.NET)
  apps/api/Controllers/ListingsController.cs             — class ListingsController
  apps/api/Controllers/UsersController.cs                — class UsersController
```

The BA agent reads this index and picks 3-8 relevant files — instead of scanning the whole codebase. This reduces token usage by ~80%.

---

## How it works

The script reads `project.config.md → stack` to detect your frontend/backend/database stack, then scans only the relevant patterns:

- Angular: `*.routes.ts`, `*.page.ts`, `*.component.ts`, `*.service.ts`, `*.store.ts`
- .NET: `*Controller.cs`, `*Handler.cs`, `*Service.cs`, `*Entity.cs`, `*DbContext.cs`
- SQL: `*/Migrations/*.cs`

Files in `node_modules`, `dist`, `.angular`, `obj`, `bin` are excluded.
