#!/usr/bin/env bash
# =============================================================================
# test-guard.sh — the testing gate: no changed source file ships without a test.
#
# Compares the current branch against base_branch, maps every changed source
# file to its expected test file(s), and reports the gaps. The skill that
# governs when/why this runs is .devpilot/skills/test-guard.md.
#
#   bash scripts/test-guard.sh [base-branch]     # report; exit 0
#   STRICT=1 bash scripts/test-guard.sh          # exit 1 when any gap exists
#
# A file counts as covered when a test file exists that references its basename:
#   foo.ts        → foo.spec.ts | foo.test.ts(x)
#   Foo.cs        → FooTests.cs | FooTest.cs | Foo.Tests.cs
#   foo.py        → test_foo.py | foo_test.py
#   foo.go        → foo_test.go
#   Foo.java      → FooTest.java | FooTests.java | FooIT.java
# Exemptions (never require a test): test files themselves, migrations,
# generated code, type-only/interface files, config, docs, styles, templates.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

BASE="${1:-}"
if [ -z "$BASE" ]; then
  BASE=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 \
    | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
fi
BASE="${BASE:-develop}"

# Diff range: merge-base when the base exists, else staged+unstaged changes.
if git rev-parse --verify --quiet "$BASE" >/dev/null || git rev-parse --verify --quiet "origin/$BASE" >/dev/null; then
  REF="$BASE"; git rev-parse --verify --quiet "$BASE" >/dev/null || REF="origin/$BASE"
  CHANGED=$(git diff --name-only --diff-filter=ACMR "$REF"...HEAD 2>/dev/null; git diff --name-only --diff-filter=ACMR 2>/dev/null)
else
  CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null; git diff --name-only --diff-filter=ACMR --cached 2>/dev/null)
fi
CHANGED=$(printf '%s\n' "$CHANGED" | sort -u | grep -v '^$' || true)

is_test_file() {
  printf '%s' "$1" | grep -qiE '(\.spec\.|\.test\.|_test\.|(^|/)test_|Tests?\.cs$|\.Tests/|Test(s|IT)?\.java$|_test\.go$|(^|/)(tests?|__tests__|spec|e2e|cypress|playwright)/)'
}

is_exempt() {
  printf '%s' "$1" | grep -qiE '(migrations?/|(^|/)(docs|perf|scripts|\.github|\.claude|\.devpilot|\.opencode)/|\.md$|\.json$|\.ya?ml$|\.toml$|\.lock$|\.csproj$|\.sln$|\.config$|\.props$|\.s?css$|\.html$|\.svg$|\.env|\.gitignore|\.d\.ts$|\.g\.cs$|\.designer\.cs$|generated|(^|/)(main|program|index|app\.config|app\.routes)\.(ts|cs|py|go|java)$|module\.ts$)'
}

# All test-ish files in the repo, once (tracked files only — cheap and exact).
TEST_POOL=$(git ls-files | grep -iE '(\.spec\.|\.test\.|_test\.|(^|/)test_|Tests?\.cs$|Test(s|IT)?\.java$|_test\.go$|(^|/)(tests?|__tests__|spec)/)' || true)

has_test() {
  local src="$1" base stem
  base=$(basename "$src"); stem="${base%.*}"
  [ -z "$stem" ] && return 1
  printf '%s\n' "$TEST_POOL" | grep -qiF "$stem" && return 0
  # Last chance: a test file that mentions the symbol/file name in its content.
  [ -n "$TEST_POOL" ] && grep -rliF --include='*' "$stem" $TEST_POOL >/dev/null 2>&1 && return 0
  return 1
}

MISSING=""; COVERED=0; SKIPPED=0; NEW_TESTS=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx|*.cs|*.py|*.go|*.java|*.vue) : ;;
    *) SKIPPED=$((SKIPPED + 1)); continue ;;
  esac
  if is_test_file "$f"; then NEW_TESTS=$((NEW_TESTS + 1)); continue; fi
  if is_exempt "$f";   then SKIPPED=$((SKIPPED + 1));   continue; fi
  [ -f "$f" ] || { SKIPPED=$((SKIPPED + 1)); continue; }
  if has_test "$f"; then
    COVERED=$((COVERED + 1))
  else
    MISSING="${MISSING}  ❌ $f
"
  fi
done <<EOF
$CHANGED
EOF

N_MISSING=$(printf '%s' "$MISSING" | grep -c '❌' || true)

echo "── test-guard (vs $BASE) ─────────────────────────────"
echo "  covered: $COVERED   new/changed tests: $NEW_TESTS   exempt: $SKIPPED   missing: $N_MISSING"
if [ "$N_MISSING" -gt 0 ]; then
  echo ""
  echo "  Changed source files with NO covering test:"
  printf '%s' "$MISSING"
  echo ""
  echo "  Fix: write the test (see .devpilot/skills/test-case-design.md), or document"
  echo "  a justified exemption in the PR description. Run /dp-test to generate them."
fi
echo "──────────────────────────────────────────────────────"

if [ "${STRICT:-0}" = "1" ] && [ "$N_MISSING" -gt 0 ]; then exit 1; fi
exit 0
