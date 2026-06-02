#!/usr/bin/env bash
# =============================================================================
# tests/run.sh — devpilot script test suite (no external deps, plain bash).
#   bash tests/run.sh
# Exit non-zero if any assertion fails.
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
no() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
assert_eq()       { if [ "$1" = "$2" ]; then ok "$3"; else no "$3 (got '$1', want '$2')"; fi; }
assert_contains() { if printf '%s' "$1" | grep -qF -- "$2"; then ok "$3"; else no "$3 (missing '$2')"; fi; }
assert_code()     { if [ "$1" = "$2" ]; then ok "$3"; else no "$3 (exit $1, want $2)"; fi; }

# A throwaway git repo with the scripts + a minimal config.
sandbox() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t; git -C "$d" config user.name t
  mkdir -p "$d/scripts" "$d/docs/tasks"
  cp "$REPO"/scripts/*.sh "$d/scripts/"
  cat > "$d/project.config.md" <<'EOF'
base_branch: develop
tracker:
  type: local
merge_policy: auto
stack:
  backend: node
EOF
  echo "$d"
}

echo "== run-mode.sh =="
eval "$(bash "$REPO/scripts/run-mode.sh" "--opencode build a thing")"
assert_eq "$RUN_MODE" "opencode" "--opencode → opencode"
assert_eq "$TASK" "build a thing" "--opencode strips flag"
eval "$(bash "$REPO/scripts/run-mode.sh" "-o fix header")";    assert_eq "$RUN_MODE" "opencode" "-o → opencode"
eval "$(bash "$REPO/scripts/run-mode.sh" "--claude do x")";    assert_eq "$RUN_MODE" "claude" "--claude → claude"
eval "$(bash "$REPO/scripts/run-mode.sh" "no flag here")";     assert_eq "$RUN_MODE" "claude" "no flag → config/claude default"

echo "== track.sh (local) =="
D=$(sandbox)
KEY=$(cd "$D" && bash scripts/create-jira-ticket.sh "Add logout" "story" "Task")
assert_contains "$KEY" "LOCAL-" "local ticket key prefix"
TNUM=$(printf '%s' "$KEY" | grep -oE '[0-9]+' | head -1)
assert_eq "${TNUM:+ok}" "ok" "key has a numeric part (branch-safe)"
( cd "$D" && bash scripts/add-jira-comment.sh "$KEY" "started" >/dev/null 2>&1 )
( cd "$D" && bash scripts/update-jira-status.sh "$KEY" "In Progress" >/dev/null 2>&1 )
LOG=$(cat "$D/docs/tasks/$KEY.md" 2>/dev/null || echo "")
assert_contains "$LOG" "started" "comment logged to task file"
assert_contains "$LOG" "In Progress" "status logged to task file"
rm -rf "$D"

echo "== scope.sh =="
D=$(sandbox)
mkdir -p "$D/docs"
cat > "$D/docs/project-index.md" <<'EOF'
# Project Index
## Components
  src/app/header/logout.component.ts          — LogoutComponent
  src/auth/LoginController.cs                  — LoginController
  src/orders/OrderService.cs                   — OrderService
EOF
OUT=$(cd "$D" && bash scripts/scope.sh "add a logout button to the header" 2>/dev/null)
assert_contains "$OUT" "logout.component.ts" "scope ranks the matching file"
FIRST=$(printf '%s\n' "$OUT" | grep -E '^\s*\[[0-9]+\]' | head -1)
assert_contains "$FIRST" "logout" "best match ranked first"
rm -rf "$D"

echo "== scope-guard.sh =="
D=$(sandbox)
( cd "$D" && echo "x" > a.component.ts && git add a.component.ts )
set +e
( cd "$D" && STRICT=1 bash scripts/scope-guard.sh backend >/dev/null 2>&1 ); GC=$?
set -e 2>/dev/null || true
assert_code "$GC" "1" "STRICT backend flags a .component.ts change"
set +e
( cd "$D" && STRICT=1 bash scripts/scope-guard.sh frontend >/dev/null 2>&1 ); GC2=$?
assert_code "$GC2" "0" "frontend layer allows the .component.ts change"
rm -rf "$D"

echo "== open-pr.sh =="
set +e
bash "$REPO/scripts/open-pr.sh" >/dev/null 2>&1; OC=$?
assert_code "$OC" "1" "open-pr with no args → exit 1"

echo "== scope-hook.sh =="
D=$(sandbox)
( cd "$D" && mkdir -p .devpilot && echo backend > .devpilot/.scope-lock )
set +e
printf '{"tool_input":{"file_path":"src/x.component.ts"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HC=$?
assert_code "$HC" "2" "lock=backend blocks a .component.ts write"
printf '{"tool_input":{"file_path":"src/Api/Foo.cs"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HA=$?
assert_code "$HA" "0" "lock=backend allows a .cs write"
( cd "$D" && rm -f .devpilot/.scope-lock )
printf '{"tool_input":{"file_path":"anything.html"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HN=$?
assert_code "$HN" "0" "no lock → allow"
rm -rf "$D"

echo "== doctor.sh / status.sh / metrics.sh / audit.sh run cleanly =="
D=$(sandbox)
set +e
( cd "$D" && bash scripts/doctor.sh >/dev/null 2>&1 ); assert_code "$?" "0" "doctor exits 0 on a sane sandbox"
( cd "$D" && bash scripts/status.sh >/dev/null 2>&1 ); assert_code "$?" "0" "status runs"
( cd "$D" && bash scripts/metrics.sh >/dev/null 2>&1 ); assert_code "$?" "0" "metrics runs"
( cd "$D" && bash scripts/audit.sh >/dev/null 2>&1 ); assert_code "$?" "0" "audit runs (no manifest)"
rm -rf "$D"

echo "== changelog.sh =="
set +e
bash "$REPO/scripts/changelog.sh" >/dev/null 2>&1; assert_code "$?" "1" "changelog with no version → exit 1"

echo "== resolve-engine.sh =="
D=$(mktemp -d)
git -C "$D" init -q
mkdir -p "$D/scripts"
cp "$REPO/scripts/resolve-engine.sh" "$D/scripts/"
cat > "$D/project.config.md" <<'EOF'
engines:
  orchestrator: claude
  coding: opencode
  runner: claude
  fallback: opencode

layer_overrides:
  frontend:    ""
  backend:     "opencode"
  db:          ""
  integration: ""

coding_models:
  opencode:
    # Non-Copilot ids on purpose: resolve-engine only strips github-copilot/* when
    # Copilot is unavailable in opencode, which is non-deterministic in CI (opencode
    # isn't installed). A plain opencode model exercises override + per-tier lookup cleanly.
    power:    "opencode/grok-code"
    standard: "opencode/grok-code"
    lite:     "opencode/grok-code-mini"
  ollama:
    power:    "ollama/deepseek-coder-v2:16b"
    standard: "ollama/deepseek-coder-v2:16b"
    lite:     "ollama/qwen2.5-coder:7b"
EOF
# runner=claude couples coding back to claude
EFF=$( cd "$D" && bash scripts/resolve-engine.sh effective )
assert_contains "$EFF" "CODING=claude" "runner=claude forces coding=claude"
# frontend has no override → coupling keeps it on claude (no model)
FE=$( cd "$D" && bash scripts/resolve-engine.sh layer frontend )
assert_contains "$FE" "LAYER_ENGINE=claude" "no override under claude runner → claude"
# backend override wins over coupling → opencode + its model
BE=$( cd "$D" && bash scripts/resolve-engine.sh layer backend )
assert_contains "$BE" "LAYER_ENGINE=opencode" "layer override beats claude coupling"
assert_contains "$BE" "opencode/grok-code" "override resolves opencode backend model (standard tier)"
# local routing swaps in the ollama model
BL=$( cd "$D" && DEVPILOT_LOCAL=1 bash scripts/resolve-engine.sh layer backend )
assert_contains "$BL" "ollama/deepseek-coder-v2:16b" "DEVPILOT_LOCAL=1 → ollama model"
# complexity suggestion
SG=$( cd "$D" && bash scripts/resolve-engine.sh suggest "refactor the auth schema across services" )
assert_contains "$SG" "COMPLEXITY=high" "architectural task → high complexity"
rm -rf "$D"

echo "== preflight-scan.sh / run-summary.sh =="
D=$(mktemp -d)
git -C "$D" init -q; git -C "$D" config user.email t@t.t; git -C "$D" config user.name t
mkdir -p "$D/scripts"
cp "$REPO/scripts/preflight-scan.sh" "$REPO/scripts/run-summary.sh" "$REPO/scripts/track.sh" "$D/scripts/"
printf 'base_branch: develop\ntracker:\n  type: local\n' > "$D/project.config.md"
( cd "$D" && git checkout -q -b develop && echo a > a.txt && git add a.txt project.config.md scripts && git commit -qm base )
PF=$( cd "$D" && bash scripts/preflight-scan.sh "fix the a file" pf-test )
assert_contains "$PF" "docs/preflight/pf-test.md" "preflight writes a brief path"
assert_contains "$(cat "$D/$PF" 2>/dev/null)" "Pre-flight scan" "preflight brief has a header"
( cd "$D" && git checkout -q -b feature/y && echo b >> a.txt && git commit -qam "fix(core): edit a" )
RS=$( cd "$D" && bash scripts/run-summary.sh LOCAL-1 sum-test "root cause text" "3 passed" develop )
assert_contains "$RS" "docs/summaries/sum-test.md" "run-summary writes a summary path"
assert_contains "$(cat "$D/$RS" 2>/dev/null)" "root cause text" "summary includes root cause"
rm -rf "$D"

echo "== process-logging policy (core-rules #11) =="
# The policy: each /ceo flow posts only a start + DONE comment to the ticket
# (plus BLOCKED as the exception). Routine progress comments must not creep back.
assert_contains "$(cat "$REPO/.devpilot/skills/core-rules.md")" "Process logging" "core-rules documents the policy"
ROUTINE_RE='add-jira-comment.sh "\$KEY" "(✅ QA passed|✅ Layer-Locked QA Passed|✅ Merged into|✅ Layer-Locked PR merged|📋 Plan complete|⚙️ Implementation complete|⚙️ Fix implemented)'
# Glob the actual command set so this never goes stale when commands are renamed.
for CMD in "$REPO"/.claude/commands/*.md; do
  f=$(basename "$CMD")
  n=$(grep -cE "$ROUTINE_RE" "$CMD"); n=${n:-0}
  assert_eq "$n" "0" "$f posts no routine progress comments"
  p=$(grep -cE 'run-summary\.sh.*--post' "$CMD"); p=${p:-0}
  assert_eq "$p" "0" "$f drops redundant run-summary --post"
done

echo "== model-profiles.sh =="
MP="$REPO/scripts/model-profiles.sh"
# claude profile → tier mapping
assert_contains "$(bash "$MP" claude-map auto)"     "POWER=claude-opus-4-8"   "claude auto uses Opus for power"
assert_contains "$(bash "$MP" claude-map balanced)" "POWER=claude-sonnet-4-6" "claude balanced caps power at Sonnet"
assert_contains "$(bash "$MP" claude-map save)"     "STANDARD=claude-haiku-4-5-20251001" "claude save defaults standard to Haiku"
assert_code "$(bash "$MP" claude-map bogus >/dev/null 2>&1; echo $?)" "1" "claude-map rejects an unknown profile"
# opencode map falls back to curated defaults when opencode is absent
assert_contains "$(bash "$MP" opencode-map recommended)" "POWER=github-copilot/gpt-5" "opencode recommended power default"
# antigravity map emits the tier keys (blank values when the CLI is absent — no guessed ids)
assert_contains "$(bash "$MP" antigravity-map recommended)" "POWER=" "antigravity map emits tier keys"
assert_code "$(bash "$MP" antigravity-map bogus >/dev/null 2>&1; echo $?)" "1" "antigravity-map rejects an unknown profile"
# apply writes coding_profile + tiers + syncs agent frontmatter, idempotently
D=$(sandbox); cp "$REPO"/project.config.md "$D/"; mkdir -p "$D/.claude/agents"
cp "$REPO"/.claude/agents/team-ba.md "$REPO"/.claude/agents/team-lead.md "$REPO"/.claude/agents/team-qa.md "$D/.claude/agents/" 2>/dev/null
( cd "$D" && bash scripts/model-profiles.sh apply claude save >/dev/null 2>&1 )
( cd "$D" && bash scripts/model-profiles.sh apply claude save >/dev/null 2>&1 )   # twice → must stay single line
assert_eq "$(grep -c 'coding_profile:' "$D/project.config.md")" "1" "apply is idempotent (one coding_profile line)"
assert_contains "$(cat "$D/project.config.md")" "coding_profile: save" "apply records the profile"
assert_contains "$(grep '^model:' "$D/.claude/agents/team-lead.md")" "claude-haiku-4-5-20251001" "apply syncs agent frontmatter (save → Haiku lead)"
# sync-agents re-applies frontmatter from project.config.md (the --update repair path)
( cd "$D" && sed -i 's/^model: .*/model: claude-sonnet-4-6/' .claude/agents/team-lead.md && bash scripts/model-profiles.sh sync-agents >/dev/null 2>&1 )
assert_contains "$(grep '^model:' "$D/.claude/agents/team-lead.md")" "claude-haiku-4-5-20251001" "sync-agents restores frontmatter from config"
# apply antigravity switches the recorded profile and leaves a single coding_profile line
( cd "$D" && bash scripts/model-profiles.sh apply antigravity recommended >/dev/null 2>&1 )
assert_eq "$(grep -c 'coding_profile:' "$D/project.config.md")" "1" "apply antigravity keeps one coding_profile line"
assert_contains "$(cat "$D/project.config.md")" "coding_profile: recommended" "apply antigravity records the profile"
rm -rf "$D"

echo ""
echo "── Results: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
