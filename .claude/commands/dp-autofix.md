# /dp-autofix — Drive a PR to green and merge it

Input: **$ARGUMENTS** — a PR number/URL, or empty = the most recent open
devpilot PR into `base_branch`.

Babysit one PR to its terminal state: diagnose red CI, fix it, re-run the
gates, and merge when everything is green — within hard bounds. The contract
is `.devpilot/skills/auto-merge.md`; read it first, it governs this command.

> ## 🔌 Transport — `gh` CLI **or** GitHub MCP (pick what's present)
> Every PR action below (read status, fetch logs, merge) is shown with the `gh`
> CLI, but **`gh` is not available in every environment** — notably Claude Code on
> the web/remote, where it is absent and these commands silently fail. **That is the
> usual reason "auto-merge didn't work even though `merge_policy: auto` is set."**
> Detect once and use the matching transport for *all* steps:
> ```bash
> if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then GH=1; else GH=0; fi
> ```
> - `GH=1` → use the `gh` commands as written.
> - `GH=0` → use the **GitHub MCP tools** for the same actions (load schemas via
>   ToolSearch first): `mcp__github__pull_request_read` (PR details / mergeable /
>   status checks), `mcp__github__get_job_logs` (failed-run logs),
>   `mcp__github__merge_pull_request` (squash merge), `mcp__github__create_pull_request`.
>   Never report auto-merge as done unless the merge tool actually returned success.

---

## Step 0 — Load policy + the PR

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
MERGE_POLICY=$(grep '^merge_policy:' project.config.md | head -1 | awk '{print $2}')
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then GH=1; else GH=0; fi
```
- `GH=1`: `gh pr view $ARGUMENTS --json number,headRefName,baseRefName,mergeable,statusCheckRollup` then `gh pr checkout $ARGUMENTS`.
- `GH=0`: read the PR with `mcp__github__pull_request_read` (get its number, head/base, `mergeable`, and the status-check rollup); check the branch out locally with `git fetch origin <headRef> && git checkout <headRef>`.

Read `.devpilot/skills/auto-merge.md`. If any **never-auto-merge** condition
holds (release-branch target, unvetted migrations, secrets/auth config in the
diff), stop now and report why — don't burn fix cycles on a PR a human must own.

## Step 1 — The fix loop (max 3 cycles)

For each cycle:
1. **Update the branch** if base moved: `git pull --rebase origin $BASE_BRANCH`.
2. **Fetch the failures** — `GH=1`: `gh pr checks`, then `gh run view <id> --log-failed`
   for each red check. `GH=0`: `mcp__github__pull_request_read` for the check rollup, then
   `mcp__github__get_job_logs` (failed jobs) for each red check. Read the complete log, not the last line.
3. **Fix per `.devpilot/skills/self-heal.md`** — 3 attempts per failure, hard
   rules apply (no skipped tests, no weakened assertions, no `ts-ignore`).
   Review comments on the PR are `/dp-review-fix`'s job — leave them alone
   unless one is the cause of the red check.
4. **Re-run the local ladder before pushing** — build, full test suite,
   `STRICT=1 bash scripts/test-guard.sh`, `bash scripts/audit.sh`. Push only a
   locally-green commit: `fix(ci): <what>`.
5. Wait for CI on the new head; green → Step 2, red → next cycle.

After 3 cycles still red → stop. Report the self-heal escalation template
(exact failing command, full error, attempts made) and leave the PR open.

## Step 2 — Merge per policy

All ladder gates green on the **head commit** (build/tests, audit, no open 🔴
review, QA PASS, CI green):

```bash
if [ "$MERGE_POLICY" != "auto" ]; then
  echo "pr-only policy — PR is green and ready for human merge"   # stop here
fi
```
When `MERGE_POLICY = auto`, perform the squash-merge with the active transport:
- `GH=1` → `gh pr merge $ARGUMENTS --squash --delete-branch`
- `GH=0` → `mcp__github__merge_pull_request` with `merge_method: "squash"`, then delete the
  head branch. **Confirm the tool returned `merged: true`** before claiming success — if it
  reports the PR is not mergeable (failing required checks, conflicts), treat it as a red gate,
  not a merge.

On merge: move the PR's Stories to Done, post the single DONE comment
(`core-rules.md` #11), and notify:
```bash
bash scripts/notify.sh done "PR #<n> green and merged into $BASE_BRANCH (<cycles> fix cycles)"
```
On escalation: `bash scripts/notify.sh blocked "PR #<n> still red after 3 fix cycles: <diagnosis>"`.

## Report

```
🤖 /dp-autofix — PR #<n> → <BASE_BRANCH>
Cycles used:   <0–3>  ·  Fixes: <commit list or "none needed">
Gate ladder:   build ✅ · tests ✅ · audit ✅ · review ✅ · QA ✅ · CI ✅
Outcome:       MERGED | READY (pr-only) | ESCALATED (<why>)
```
