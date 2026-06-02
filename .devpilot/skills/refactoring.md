# Refactoring — change structure, not behavior

Load this **before restructuring code without changing what it does** (renaming, extracting,
splitting, de-duplicating, paying down `tech-debt`). The discipline is what keeps it safe.

## The one rule
**Refactoring never changes observable behavior.** If behavior changes, it's a feature/fix —
do that separately, in its own commit/PR (see `version-control`).

## Method
1. **Green first** — there must be passing tests covering the code you'll touch. If there aren't,
   write **characterization tests** that pin current behavior *before* you change anything (see `test-strategy`).
2. **Small steps** — one transformation at a time (extract function, rename, inline, move).
   Run tests after each step; stay green the whole way.
3. **Commit per refactor** — small, labeled `refactor(scope): …`. Easy to review, easy to revert.
4. **Don't gold-plate** — refactor in service of the task at hand or a tracked debt item, not a rabbit hole (`core-rules` #8).

## Common safe moves
Extract function/variable to name intent · introduce a guard clause to flatten nesting ·
replace magic value with a constant · de-duplicate real (not coincidental) repetition ·
split a multi-job function/class.

## Ship-with
- [ ] Tests covered the code before the change and still pass — unchanged in intent.
- [ ] No behavior change snuck in; refactor commits are isolated from feature/fix commits.
- [ ] Result is simpler than before (see `clean-code`); no new public-API breakage.
