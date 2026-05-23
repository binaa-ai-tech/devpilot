# Pull Request

**Ticket:** [<KEY>](https://<your-jira>/browse/<KEY>)
**Type:** feature | bug | refactor | hotfix | chore

## What changed

<2–4 sentences. What this PR does, in plain language.>

## Why

<The reason. For bugs: root cause, not just the symptom.>

## How (technical summary)

- <Key change 1>
- <Key change 2>

## Acceptance criteria

- [ ] <Copied from ticket — checked off>
- [ ] <Copied from ticket — checked off>

## Tests

- [ ] Unit tests added / updated
- [ ] `npm test` green
- [ ] `npm run lint` clean
- [ ] `npm run build` clean
- [ ] Manual smoke done (describe below)

**Manual smoke:** <what you clicked / verified>

## Rules compliance (`.aidev/rules.md`)

- [ ] No `any`
- [ ] `takeUntilDestroyed` on all subscriptions
- [ ] `OnPush` on new components
- [ ] New control-flow syntax (`@if` / `@for`)
- [ ] Tests for new logic
- [ ] No commented-out code
- [ ] No hardcoded secrets / magic values

## DB impact

- Migrations: <yes/no — link>
- SPs/triggers touched: <list>
- Verified across: [ ] dev [ ] UAT [ ] prod-ready

## Screenshots / recordings

<For UI changes.>

## Rollback

<How to revert if needed.>
