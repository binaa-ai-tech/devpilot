# Impact Map — <TICKET-KEY>

> Output of Step 2 (Investigation). Written BEFORE any code change.

## Summary

<One paragraph: what's changing and why.>

## Files to touch

| File          | Change type | Reason |
| ------------- | ----------- | ------ |
| `src/app/...` | modify      |        |
| `src/app/...` | create      |        |

## Files NOT to touch

- <Explicit out-of-scope list>

## Data / schema impact

- Tables affected: <list, or "none">
- Migrations needed: <yes/no — link script>
- Stored procedures touched: <list>
- Triggers affected: <list — high-risk, double-check across envs>

## API impact

- Endpoints added/changed/removed: <list>
- Breaking changes: <yes/no>
- Consumers affected: <list>

## Test surface

- Existing tests to update: <list>
- New tests to add: <list>
- Manual smoke checks: <list>

## Risks

| Risk | Likelihood | Mitigation |
| ---- | ---------- | ---------- |
|      |            |            |

## Rollback plan

<How to revert if this goes wrong in prod.>
