# Skill: Spec-First (Spec Driven Development)

## Principle

The spec is the source of truth. Nothing is built that is not in the spec. Nothing in the spec is skipped.

## Rules — enforced at every phase

### For BA (writing requirements)
- Every acceptance criterion must be independently verifiable — a developer must be able to write an automated test that proves it
- State what the system must do, not how it does it
- Every edge case explicitly listed is a required test — not optional
- Ambiguity in the spec is a defect. Rewrite vague criteria until they are testable.

### For Team Lead (planning)
- Every item in the implementation plan must trace to at least one acceptance criterion
- If you cannot point to the AC that justifies a planned change, remove the change from the plan
- Scope additions not in the requirements doc must be flagged and rejected unless the user approves

### For Developers (implementation)
- Read `docs/requirements/<slug>.md` **before writing a single line of code**
- For each acceptance criterion, identify the exact code change that satisfies it
- Do not implement features, states, or behaviors not described in the requirements — that is scope creep and counts as a defect
- When you finish a logical unit of work, verify it against the AC it satisfies before moving to the next
- If the plan contradicts the requirements, **requirements win** — flag it and follow the requirements

### For QA (verification)
- Every acceptance criterion in the requirements doc must have a corresponding test
- A test that "passes" but would not catch a broken implementation is not a valid test — apply mutation-mindset
- If a feature exists in the code but not in the requirements, flag it as out-of-scope (not automatically a blocker, but must be noted)
- QA verdict is based on requirements coverage, not on subjective code quality

## Scope creep is a defect

If it's not in the spec:
- Do not build it
- Do not test it
- Do not plan for it

Document it as a future task instead.

## The spec hierarchy

```
Task description
    ↓ (BA transforms)
Requirements doc (docs/requirements/<slug>.md)
    ↓ (Team Lead traces)
Implementation plan (docs/plans/<slug>.md)
    ↓ (Developers implement)
Code changes
    ↓ (QA verifies)
Every AC checked and passing
```

Every arrow must be traceable. If a code change cannot be traced back to an AC, it should not exist.
