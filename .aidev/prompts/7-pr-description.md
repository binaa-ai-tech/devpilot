# Prompt — Step 7: Generate PR Description + Changelog

```
Generate a PR description using `.aidev/templates/pr-description.md` and a
changelog entry using `.aidev/templates/changelog-entry.md`.

Inputs:
- Ticket: <paste ticket>
- Diff summary: <paste `git diff --stat main...HEAD` or full diff>
- Self-review report: <paste output of Step 5 prompt>

Rules:
- For bugs: PR description MUST include root cause, not just symptom.
- "Why" section is mandatory. No empty "TBD" placeholders.
- All rules-compliance checkboxes in the template must be evaluated honestly:
  check only what's actually true in the diff.
- Changelog entry: one line, user-facing language (not implementation detail).
- For internal-only changes (refactor/chore), tag changelog category as
  "Changed" with "(internal)" suffix so users skim past it.

Output:
1. The PR description in markdown, ready to paste into GitHub
2. The changelog entry line, ready to paste into CHANGELOG.md
```
