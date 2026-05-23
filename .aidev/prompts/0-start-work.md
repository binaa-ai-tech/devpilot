# Start Work — Full Automated Flow

When the user describes a task, execute all stages without stopping.

## Stages (run in order, no approval pauses)

### 1. Create Jira ticket

```bash
./scripts/create-jira-ticket.sh "<summary>" "<description>" "<Story|Bug|Task>"
```

Note the ticket key (e.g. MSK-5).

### 2. Triage + Impact map

- Read the codebase relevant to the task
- Write `.aidev/impact-maps/<KEY>.md` using `.aidev/templates/impact-map.md`
- Follow `.aidev/rules.md`

### 3. Create branch

```bash
./scripts/new-feature.sh <KEY> <short-slug>
```

### 4. Implement with opencode

```bash
opencode
```

Use model `github-copilot/gpt-5.4-codex`. Paste prompt from `4-copilot-implement.md` with the ticket key and impact map.

### 5. Self-review

```bash
git diff main...HEAD
```

Run review against `.aidev/rules.md` per `5-self-review.md`.

- ✅ or ⚠️ fixed → continue
- ❌ BLOCKERS → fix then re-review before continuing

### 6. Commit + push + open PR

```bash
git add -A
git commit -m "feat(<scope>): <description> [<KEY>]"
git push origin <branch>
gh pr create --title "<KEY>: <description>" --body "..."
```

## Stop conditions (only these cause a pause)

- ❌ Blockers in self-review that cannot be auto-fixed
- Build or lint failure that cannot be resolved automatically
- Ambiguity in the task that changes the scope significantly

## Done

Report to user:

- Jira ticket URL
- PR URL
- What was implemented (3 bullet points max)
- "Check your email when CI passes, then test on SIT"
