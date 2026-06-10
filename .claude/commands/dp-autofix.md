# /dp-autofix — Drive a PR to green and merge it

Input: **$ARGUMENTS** — a PR number/URL, or empty = the most recent open
devpilot PR into `base_branch`.

Babysit one PR to its terminal state: diagnose red CI, fix it, re-run the
gates, and merge when everything is green — within hard bounds. The contract
is `.devpilot/skills/auto-merge.md`; read it first, it governs this command.

---

## Step 0 — Load policy + the PR

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
MERGE_POLICY=$(grep '^merge_policy:' project.config.md | head -1 | awk '{print $2}')
gh pr view $ARGUMENTS --json number,headRefName,baseRefName,mergeable,statusCheckRollup
gh pr checkout $ARGUMENTS
```

Read `.devpilot/skills/auto-merge.md`. If any **never-auto-merge** condition
holds (release-branch target, unvetted migrations, secrets/auth config in the
diff), stop now and report why — don't burn fix cycles on a PR a human must own.

## Step 1 — The fix loop (max 3 cycles)

For each cycle:
1. **Update the branch** if base moved: `git pull --rebase origin $BASE_BRANCH`.
2. **Fetch the failures** — `gh pr checks`, then `gh run view <id> --log-failed`
   for each red check. Read the complete log, not the last line.
3. **Fix per `.devpilot/skills/self-heal.md`** — 3 attempts per failure, hard
   rules apply (no skipped tests, no weakened assertions, no `ts-ignore`).
   Review comments on the PR are `/dp-review-fix`'s job — leave them alone
   unless one is the cause of the red check.
4. **Re-run the local ladder before pushing** — build, full test suite,
   `bash scripts/audit.sh`. Push only a locally-green commit: `fix(ci): <what>`.
5. Wait for CI on the new head; green → Step 2, red → next cycle.

After 3 cycles still red → stop. Report the self-heal escalation template
(exact failing command, full error, attempts made) and leave the PR open.

## Step 2 — Merge per policy

All ladder gates green on the **head commit** (build/tests, audit, no open 🔴
review, QA PASS, CI green):

```bash
if [ "$MERGE_POLICY" = "auto" ]; then
  gh pr merge $ARGUMENTS --squash --delete-branch
else
  echo "pr-only policy — PR is green and ready for human merge"
fi
```

On merge: move the PR's Stories to Done and post the single DONE comment
(`core-rules.md` #11).

## Report

```
🤖 /dp-autofix — PR #<n> → <BASE_BRANCH>
Cycles used:   <0–3>  ·  Fixes: <commit list or "none needed">
Gate ladder:   build ✅ · tests ✅ · audit ✅ · review ✅ · QA ✅ · CI ✅
Outcome:       MERGED | READY (pr-only) | ESCALATED (<why>)
```
