# Step 4 — Implement with GitHub Copilot (via opencode)

> Claude produced the plan (Step 2 impact map). Now run opencode in the terminal to implement.

---

## Before you start

Confirm you have `.aidev/impact-maps/<KEY>.md` with files to touch and logic per file.

---

## Run opencode

```bash
cd /path/to/maskan
opencode
```

Inside opencode, switch model to `github-copilot/gpt-5.4-codex` (best for code generation).

Then paste this prompt:

```
Follow the rules in `.aidev/rules.md` strictly. No questions — implement fully.

Read these files first:
1. `.aidev/rules.md`
2. `.aidev/impact-maps/<KEY>.md`

Ticket:
"""
<paste ticket description and acceptance criteria>
"""

Rules reminder:
- Angular: standalone, OnPush, signals not BehaviorSubject
- Subscriptions: always takeUntilDestroyed(this.destroyRef)
- Templates: @if / @for only — no *ngIf / *ngFor
- Types: no `any` — explicit types or unknown + narrowing
- SCSS: design tokens only — no hardcoded hex or px
- Tests: one *.spec.ts per new component/service
- No console.log

Implement every file listed under "Files to touch" in the impact map.
After all files are done, run: npm run lint && npm test -- --passWithNoTests
Fix any errors before finishing.

When done, output:
- Files created/modified (one line each)
- Assumptions made
- Confirmation lint/test passed
- Suggested commit messages (Conventional Commits, include ticket key)
```

---

## After opencode finishes

Verify locally:

```bash
npm run lint
npm test -- --passWithNoTests
dotnet build apps/api -c Release   # if API files changed
```

---

## Then hand to Claude for review (Step 5)

```bash
git diff main...HEAD
```

Paste into Claude with the `5-self-review.md` prompt.
