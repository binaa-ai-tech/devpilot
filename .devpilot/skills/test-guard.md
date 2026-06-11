# Test Guard — no untested change ships

**Highly recommended — load before every commit of implementation work and at
every merge gate.** `test-strategy.md` says what to test; `test-case-design.md`
says how to derive the cases; this is the *enforcement*: a mechanical check that
every changed source file has a covering test, run by `scripts/test-guard.sh`.

## When to run
- **Developers** — before the final commit of a layer's work:
  `bash scripts/test-guard.sh` (report mode).
- **Merge gates** — `/dp-build` review gate, `/dp-autofix` local ladder, and the
  `auto-merge.md` ladder run it strict: `STRICT=1 bash scripts/test-guard.sh`
  — any gap blocks the merge.
- **QA** — confirm the guard is clean before issuing a PASS verdict.

## What counts as covered
A changed source file is covered when a test file references it by name
(`foo.ts → foo.spec.ts`, `Foo.cs → FooTests.cs`, `foo.py → test_foo.py`,
`foo.go → foo_test.go`, `Foo.java → FooTest.java`). The guard checks existence
and reference, not quality — pairing it with the mutation mindset
(`test-strategy.md`) is what makes the coverage real.

## Exemptions — explicit, never silent
The guard auto-exempts migrations, generated code, type-only files, config,
docs, styles, and entry points. Anything else that genuinely needs no test:
- gets a one-line justification in the **PR description** ("X is exempt
  because …"), and
- is the exception, not the routine. Three exemptions in one PR is a smell.

## Hard rules
- Never "fix" a gap by renaming a file to look like a test, adding an empty
  test shell, or committing an assertion-free test — an empty test is worse
  than none because it reads as covered.
- Never weaken `STRICT=1` at a merge gate to get a PR through; fix the gap or
  document the exemption.
- A guard pass does **not** replace running the suite — it proves tests exist;
  the suite proves they pass.
