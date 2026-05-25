# /ceo — CEO Task Intake

Task: **$ARGUMENTS**

You are the AI development team. A task has been submitted by the CEO.
Execute it fully. The CEO's only required interactions are:
1. Answer BA clarifying questions (once, ~5 minutes)
2. Test on DEV and decide when to promote each stage

---

## Step 1 — Classify the task

Analyze the task and pick the flow:

| Type | Signals | Flow |
|------|---------|------|
| **HOTFIX** | "down", "P0", "production broken", "users can't access", "critical", "urgent" | Hotfix (expedited — skip team) |
| **BUG** | "fix", "broken", "not working", "error", "wrong", "failing", "crash" | Full team (bug framing) |
| **FEATURE** | Everything else — new capability, enhancement, user story | Full team (feature framing) |

---

## Feature or Bug → Full Team Flow

Read `.claude/commands/team-task.md` and execute all 5 phases fully for the task above.

The BA will ask clarifying questions — present them to the CEO and wait for their answers.
After receiving answers, run all remaining phases autonomously without stopping unless a BLOCKER requires human input.

---

## Hotfix → Expedited Flow

Skip the full team workflow. Speed is critical.
Read `.aidev/prompts/0-start-work.md` and jump directly to the **Hotfix flow** section.

---

## CEO Report (output when all work is done)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Task delivered, ready for your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋  Jira:    <ticket URL>
🔀  PR:      <pull request URL>

📦  What was built:
    • <bullet 1>
    • <bullet 2>
    • <bullet 3>

🔗  Test on DEV:  <DEV_FRONTEND_URL from .aidev/config.sh>
    (Live ~5 min after PR merges and CI passes)

──────────────────────────────────────────────────────
🚀  Promote when ready:

    1. DEV looks good?
       Run: /binaa-sit <version>
       Tip: git tag --sort=-version:refname | head -1
            → features bump MINOR (1.0.0 → 1.1.0)
            → bug fixes bump PATCH (1.0.0 → 1.0.1)

    2. SIT passed QA?
       Run: /binaa-uat
       (triggers UAT deployment — manual approval gate in GitHub Actions)

    3. UAT signed off?
       Run: /binaa-prd <version>
       (deploys to production — requires manual approval in GitHub Actions)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
