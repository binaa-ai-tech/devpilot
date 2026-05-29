# Skill: Estimation & Vertical Slicing

Used by the **Team Lead / BA** in planning. How a small team ships big things:
cut the work into thin slices that each deliver value and can be verified.

## Slice vertically, not horizontally
- A good slice goes end-to-end (UI → API → DB) for ONE small capability and is
  independently shippable and testable.
- Bad slice: "build all the backend", then "build all the frontend" — nothing
  works until the end.
- Start with a **walking skeleton**: the thinnest path that runs end-to-end,
  then add capability slice by slice.

## Sizing (relative, not hours)
| Size | Meaning |
|------|---------|
| **S** | one file/component, no new contracts, < ~1 slice |
| **M** | one layer or a small cross-layer slice, a few files |
| **L** | multiple layers or new contracts — **split it** into S/M slices first |

If a task is **L**, decompose before building. Route accordingly: S → fast
path, single-layer → layer-locked, multi-slice → full team flow.

## Sequencing
1. Order slices so each builds on a working state (no big-bang integration).
2. Do the riskiest / most-uncertain slice early to surface unknowns.
3. Define the acceptance criteria per slice — they are the test contract.

## Rules
- No slice without a verifiable acceptance criterion.
- Prefer shipping a thin complete slice over a thick half-built one.
- Record assumptions; don't pause to ask (see `get-shit-done.md`).
