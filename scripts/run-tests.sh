#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — token-lean test runner: full log to disk, summary to the agent.
#
# Runs the Angular (Vitest), .NET and Playwright suites it detects, writes each
# suite's complete output to .devpilot/logs/, and prints only a PASS/FAIL line
# plus the failure lines. The skill that governs its use is
# .devpilot/skills/token-lean-testing.md.
#
#   bash scripts/run-tests.sh [angular|dotnet|e2e|all]   # default: all
#   bash scripts/run-tests.sh cmd "<command>"            # wrap any command
#   bash scripts/run-tests.sh dotnet -- --filter "FullyQualifiedName~Orders"
#
# Env: TEST_MAX_LINES (failure lines shown per suite, default 40)
# Exit: 0 when every suite passed (or none was found), 1 otherwise.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

MAX_LINES="${TEST_MAX_LINES:-40}"
LOG_DIR="$ROOT/.devpilot/logs"
mkdir -p "$LOG_DIR"

MODE="${1:-all}"
[ $# -gt 0 ] && shift
CUSTOM_CMD=""
if [ "$MODE" = "cmd" ]; then
  CUSTOM_CMD="${1:-}"
  [ $# -gt 0 ] && shift
  [ -z "$CUSTOM_CMD" ] && { echo "usage: run-tests.sh cmd \"<command>\"" >&2; exit 2; }
fi
[ "${1:-}" = "--" ] && shift
EXTRA_ARGS=("$@")

# Lines worth an agent's attention: failures, compiler errors, assertion diffs, totals.
FAIL_PATTERN='FAIL|Fail|✗|×|✘|[Ee]rror|[Ee]xception|Expected|Received|Actual|Assert|expect\(|failed|Tests +[0-9]|Test Files|Passed!|Failed!|Total tests|[0-9]+ (passed|failed|flaky)'

FAILED=0
RAN=0

# find_dir <maxdepth> <name-glob...> → directory of the first match (repo-relative)
find_dir() {
  local depth="$1"; shift
  local expr=() first=1 n
  for n in "$@"; do
    [ $first -eq 0 ] && expr+=(-o)
    expr+=(-name "$n"); first=0
  done
  find . -maxdepth "$depth" \( -path ./node_modules -o -path '*/node_modules' -o -path ./.git \) -prune \
    -o \( "${expr[@]}" \) -print 2>/dev/null | head -1 | xargs -r dirname
}

# run_suite <name> <dir> <command...>
run_suite() {
  local name="$1" dir="$2"; shift 2
  local log="$LOG_DIR/$name.log" code start secs
  RAN=$((RAN + 1))
  start=$(date +%s)
  ( cd "$dir" && "$@" ) >"$log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  if [ $code -eq 0 ]; then
    echo "✅ PASS  $name  (${secs}s)  log: ${log#"$ROOT"/}"
    grep -E 'Tests +[0-9]|Passed!|Total tests|[0-9]+ passed' "$log" | tail -2 | sed 's/^/        /'
  else
    FAILED=$((FAILED + 1))
    echo "❌ FAIL  $name  (exit $code, ${secs}s)  log: ${log#"$ROOT"/}"
    local hits
    hits=$(grep -nE "$FAIL_PATTERN" "$log" | head -n "$MAX_LINES")
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits" | cut -c1-220 | sed 's/^/        /'
    else
      tail -n "$MAX_LINES" "$log" | cut -c1-220 | sed 's/^/        /'
    fi
    local total
    total=$(grep -cE "$FAIL_PATTERN" "$log")
    [ "$total" -gt "$MAX_LINES" ] && echo "        … $((total - MAX_LINES)) more matching lines in the log"
  fi
}

run_angular() {
  local dir; dir=$(find_dir 3 angular.json)
  [ -z "$dir" ] && { [ "$MODE" = "angular" ] && echo "⚠️  no angular.json found"; return; }
  run_suite angular "$dir" npx ng test --watch=false ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
}

run_dotnet() {
  local dir; dir=$(find_dir 3 '*.sln' '*.slnx')
  [ -z "$dir" ] && dir=$(find_dir 4 '*Tests.csproj' '*.Tests.csproj')
  [ -z "$dir" ] && { [ "$MODE" = "dotnet" ] && echo "⚠️  no .sln or test project found"; return; }
  run_suite dotnet "$dir" dotnet test --nologo --verbosity quiet ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
}

run_e2e() {
  local dir; dir=$(find_dir 3 'playwright.config.ts' 'playwright.config.js' 'playwright.config.mjs')
  [ -z "$dir" ] && { [ "$MODE" = "e2e" ] && echo "⚠️  no playwright.config found"; return; }
  run_suite e2e "$dir" npx playwright test --reporter=line ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
}

case "$MODE" in
  angular) run_angular ;;
  dotnet)  run_dotnet ;;
  e2e)     run_e2e ;;
  all)     run_dotnet; run_angular; run_e2e ;;
  cmd)     run_suite cmd . bash -c "$CUSTOM_CMD" ;;
  *) echo "usage: run-tests.sh [angular|dotnet|e2e|all|cmd \"<command>\"] [-- extra args]" >&2; exit 2 ;;
esac

[ $RAN -eq 0 ] && echo "ℹ️  no test suites detected"
[ $FAILED -gt 0 ] && exit 1
exit 0
