# Prompt — Step 5: Self-Review + Commit + PR

Run after opencode finishes. Pipe `git diff main...HEAD` into Claude.

```
You are reviewing the diff below against `.aidev/rules.md`. Be strict.

Diff:
"""
<paste git diff>
"""

Produce a review report with these sections:

1. BLOCKERS — must fix before merge
   - File:line — issue — required fix
2. SUGGESTIONS — should fix, not blocking
   - File:line — issue — suggested fix
3. NITS — style / consistency, optional
4. POSITIVES — what's done well (keep it short)

Check specifically for:
- `any` usage anywhere in the diff → BLOCKER
- Subscriptions without takeUntilDestroyed → BLOCKER
- New components without OnPush → BLOCKER
- New components without a corresponding *.spec.ts → BLOCKER
- Old control-flow (*ngIf / *ngFor) in new code → BLOCKER
- Hardcoded colors or px values instead of design tokens → SUGGESTION
- Commented-out code → BLOCKER
- console.log left in → BLOCKER
- Magic numbers/strings → SUGGESTION
- For SQL: missing SET XACT_ABORT/NOCOUNT, bare object names, single-row trigger assumptions → BLOCKER

End with one of:
- ✅ READY — then automatically run Steps A, B, C below
- ⚠️ FIX SUGGESTIONS BEFORE MERGE — fix then run Steps A, B, C
- ❌ BLOCKERS PRESENT — DO NOT MERGE — stop, report blockers only
```

---

## If result is ✅ or ⚠️ fixed — Claude runs these automatically:

### A. Commit

```bash
git add -A
git commit -m "<conventional commit message including ticket key>"
```

### B. Push branch

```bash
git push origin <current-branch>
```

### C. Open PR

```bash
gh pr create \
  --title "<ticket key>: <short description>" \
  --body "$(cat <<'EOF'
## Jira Ticket
[<KEY>](https://your-org.atlassian.net/browse/<KEY>)

## Description
<what was implemented>

## Changes Made
<bullet list of files changed>

## Testing Done
- [ ] Lint passed
- [ ] Tests passed
- [ ] Manual testing on SIT

## Rules Compliance
- [ ] No `any` type
- [ ] All subscriptions use `takeUntilDestroyed()`
- [ ] All new components have `ChangeDetectionStrategy.OnPush`
- [ ] New control-flow syntax used (`@if`, `@for`)
- [ ] SCSS uses design tokens
- [ ] No `console.log`
- [ ] Every new service/component has a `*.spec.ts`

## Changelog
- Added: <user-visible change>
EOF
)"
```

Then report the PR URL so you can review it.
