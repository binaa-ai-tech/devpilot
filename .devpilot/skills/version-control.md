# Version Control & PR Hygiene — small, reviewable, reversible

Load this **before structuring commits or opening a PR.** Good history is a debugging tool and
a safety net. Extends `core-rules` #2.

## Commits
- **Atomic** — one logical change per commit; it builds and passes on its own.
- **Conventional** — `feat|fix|chore|refactor|docs|test(scope): summary` in the imperative.
- **Separate refactor from behavior change** (see `refactoring`) — never mix in one commit.
- Don't commit generated files, secrets, or commented-out code.

## Branches
- Short-lived feature branches off the base; rebase/update often to avoid big-bang merges.
- Name per the project convention: `feature/<key>-<slug>`, `fix/<key>-<slug>` (see `git-flow.sh`).
- Integrate frequently — long-lived branches rot and cause painful merges.

## Pull requests
- **Small and single-purpose** — aim for < ~400 changed lines; a reviewer can hold it in their head.
  If it's bigger, split it (see `estimation-and-slicing`).
- **PR body = the technical record:** what changed, why, how it was tested, risk, screenshots/links.
  The ticket links here (see `core-rules` #11).
- **Green before review** — CI passing, self-reviewed diff, no leftover TODOs without a ticket.
- Address every review comment (fix or reply); don't force-push over an in-progress review without a note.

## Ship-with
- [ ] Commits atomic + conventional; refactors isolated.
- [ ] PR is small, single-purpose, CI-green, with a complete description.
- [ ] No secrets, generated files, or dead code in the diff. (See `code-review`, `release-discipline`.)
