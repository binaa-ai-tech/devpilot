# Domain Model: <TASK-TITLE>

**Ticket:** <JIRA-KEY>
**Date:** <DATE>
**Author:** AI Business Analyst

---

## Domain Entities

| Entity | Key Attributes | Notes |
|--------|---------------|-------|
| `<EntityName>` | `id`, `<attr1>`, `<attr2>` | <relationship or constraint notes> |

---

## Relationships

> Describe how entities relate to each other.

- `<Entity A>` has many `<Entity B>` (via `<foreignKey>`)
- `<Entity C>` belongs to one `<Entity A>`
- `<Entity D>` and `<Entity E>` have a many-to-many through `<JoinTable>`

---

## Data Flow

```
[User action]
    │
    ▼
[Frontend component]
    │  HTTP POST /api/<endpoint>
    ▼
[API Controller]
    │  calls
    ▼
[Service method]
    │  reads/writes
    ▼
[Repository → dbo.<Table>]
    │  returns
    ▼
[DTO → JSON response]
    │
    ▼
[Frontend state update]
```

---

## Domain Glossary

| Term | Definition |
|------|-----------|
| `<Term>` | <Plain-English definition as used in this project> |

---

## Business Rules

- <Rule 1: e.g. "An order cannot be cancelled after it has been shipped">
- <Rule 2: e.g. "A user can only have one active subscription at a time">
- <Rule 3: constraint or invariant>
