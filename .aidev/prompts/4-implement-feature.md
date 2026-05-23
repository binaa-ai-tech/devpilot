# Prompt — Step 4: Implement Feature (autonomous)

Use with Copilot Chat, Claude Code, or via the API (Haiku 4.5 / Sonnet 4.5).

```
You are implementing ticket <KEY> end-to-end. No clarifying questions, no
"should I continue" pauses — execute fully.

Required reading (do this first):
1. `.aidev/rules.md` — strict code rules, follow all of them
2. `.aidev/impact-maps/<KEY>.md` — your investigation plan from Step 2
3. The ticket attached below

Ticket:
"""
<paste ticket>
"""

Execution order:
1. Create/modify only the files listed in the Impact Map's "Files to touch"
2. Do NOT modify files listed under "Files NOT to touch"
3. For each new Angular component:
   - Standalone, OnPush, signal-based inputs/outputs
   - New control-flow syntax (@if / @for)
   - Use takeUntilDestroyed for any subscription
   - SCSS uses project design tokens, no hardcoded colors
4. For each new service: typed return values, no `any`, providedIn: 'root' unless feature-scoped
5. For each new component/service: add a `*.spec.ts` next to it covering
   render + one interaction or business rule
6. Update relevant module/route registration if needed
7. After all changes, run: `npm run lint`, `npm test`, `npm run build`.
   If any fail, fix and re-run until green. Do not give up and ask.

When done, output:
- Summary of files created/modified, one line each
- Any assumptions you made
- Confirmation that lint/test/build all passed
- Suggested commit messages (Conventional Commits, include ticket key)
```
