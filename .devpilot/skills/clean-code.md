# Clean Code — write for the next reader

Load this **when writing or reviewing non-trivial code.** Code is read far more than it's
written; optimize for the person who debugs it at 2am (often you). Extends `core-rules` #5–7.

## Naming
- Names reveal **intent**: `elapsedDays`, not `d`. Searchable, pronounceable, no cryptic abbreviations.
- Booleans/predicates read as questions: `isActive`, `hasAccess`. Functions are verbs; classes are nouns.
- One word per concept (don't mix `fetch`/`get`/`retrieve` for the same thing).

## Functions
- **Small and one job.** If you need "and" to describe it, split it.
- **Few parameters** (≤3); bundle related args into an object. No boolean "mode" flags — split the function.
- **Guard clauses over deep nesting** — return early; keep the happy path flat.
- **No side effects a caller can't see from the name.** Command or query, not both.

## Structure & clarity
- **No magic values** — name constants (`core-rules` #6). **No dead/commented-out code** (#5).
- **Comments explain *why*, not *what*** — the code says what. Delete comments that restate code.
- **DRY with judgment** — extract real duplication; don't over-abstract a coincidence.
- **Consistent** with the file's existing style, naming, and idioms — match the surrounding code.
- Handle errors explicitly; don't swallow exceptions.

## Ship-with
- [ ] A new reader can follow each function top-to-bottom without scrolling away.
- [ ] No magic values, dead code, or comments that just restate the code.
- [ ] Names, formatting, and patterns match the surrounding file. (See `refactoring`, `code-review`.)
