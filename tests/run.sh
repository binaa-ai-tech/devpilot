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
eval "$(bash "$REPO/scripts/run-mode.sh" "--max build a thing")"
assert_eq "$RUN_MODE" "max" "--max → max"
assert_eq "$TASK" "build a thing" "--max strips flag"
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

echo ""
echo "── Results: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
