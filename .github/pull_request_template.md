## Jira Ticket

[<KEY>-](https://your-org.atlassian.net/browse/<KEY>-)

## Description

Brief description of the changes in this PR.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update
- [ ] Refactoring
- [ ] Dependency update

## Changes Made

- Change 1
- Change 2
- Change 3

## Testing Done

Describe the tests you ran and how to reproduce the issue.

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## RTL Testing

- [ ] Tested with Arabic text (if UI changes)
- [ ] Layout verified in RTL mode

## Rules Compliance (.devpilot/rules.md)

- [ ] No `any` type used (use `unknown` + narrowing)
- [ ] All subscriptions use `takeUntilDestroyed()`
- [ ] All new components have `ChangeDetectionStrategy.OnPush`
- [ ] New state uses `signal()` / `computed()`, not `BehaviorSubject`
- [ ] New control-flow syntax used (`@if`, `@for`) — no `*ngIf` / `*ngFor`
- [ ] SCSS uses design tokens — no hardcoded hex or px values
- [ ] No `console.log` in committed code
- [ ] Every new service method / component has a `*.spec.ts`
- [ ] SQL: `SET XACT_ABORT ON` in any multi-statement block
- [ ] Secrets not in code — all via environment config

## Checklist

- [ ] `npm run lint` passes
- [ ] `npm run test` passes
- [ ] `dotnet build apps/api -c Release` passes
- [ ] Arabic/RTL tested (if UI changes)
- [ ] Impact map updated: `.devpilot/impact-maps/<TICKET>.md`

## Changelog

<!-- One line per user-visible change. Follow Keep a Changelog format. -->

- Added: ...

## Breaking Changes

Describe any breaking changes and migration path if applicable.

## Screenshots

Add screenshots or GIFs if UI/UX related.

## Deployment Notes

Any special considerations for deployment?

## Reviewers

@mention relevant reviewers
