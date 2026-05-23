# Prompt — Step 4: Implement Refactor (autonomous)

```
You are executing refactor ticket <KEY>. Behavior must not change. Autonomous,
no pauses.

Required reading:
1. `.aidev/rules.md`
2. `.aidev/impact-maps/<KEY>.md`
3. The ticket below

Ticket:
"""
<paste ticket>
"""

Hard rules:

- NO behavior changes. If you find a bug while refactoring, leave it alone and
  open a separate ticket note in your output.
- Existing tests must pass UNCHANGED. If a test must change to accommodate the
  refactor (e.g. internal API rename), that's a smell — flag it.
- Add tests for any newly-extracted unit that wasn't covered before.
- Follow `.aidev/rules.md` strictly. This is the chance to bring code up to
  standard (takeUntilDestroyed, OnPush, signal inputs, new control-flow,
  no `any`).

Common refactor patterns to use:
- Replace manual `unsubscribe()` / `Subscription` arrays with
  `takeUntilDestroyed(this.destroyRef)`
- Replace `*ngIf` / `*ngFor` with `@if` / `@for`
- Replace `BehaviorSubject` state with `signal()` where appropriate
- Replace `@Input()` / `@Output()` with `input<T>()` / `output<T>()`
- Add `ChangeDetectionStrategy.OnPush` to components that don't have it
- Remove `any` types — replace with proper interfaces

Verify: `npm run lint`, `npm test`, `npm run build` — all green.

Output:
- One-line summary per file
- Confirmation no public API changed (or list of intentional API changes)
- Confirmation tests pass unchanged
- Suggested commit: refactor(<KEY>): <summary>
```
