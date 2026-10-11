#!/usr/bin/env bash
# =============================================================================
# test-guard.sh — the testing gate: no changed source file ships without a test.
#
# Compares the current branch against base_branch, maps every changed source
# file to its expected test file(s), and reports the gaps. The skill that
# governs when/why this runs is .claude/skills/test-guard/SKILL.md.
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
#
# Durable exemption list: scripts/test-guard.exempt (override with TEST_GUARD_EXEMPT=<file>).
# One repo-relative path or glob per line, followed by a mandatory "# reason":
#   api/src/Foo/Models/BarModels.cs      # DTO records only, no behaviour
#   tools/seed-*.ts                      # one-off seed scripts, run by hand
# Globs use bash pattern matching, so "*" also crosses "/". Blank lines and lines starting
# with "#" are ignored. An entry WITHOUT a reason is rejected (warned about, exempts nothing):
# every exemption must say why, in the repo, where review sees it. Exemptions written only
# in a PR description do not count. Prefer an exact path; a glob can hide future logic.
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
  printf '%s' "$1" | grep -qiE '(migrations?/|(^|/)(docs|perf|scripts|\.github|\.claude|\.devpilot)/|\.md$|\.json$|\.ya?ml$|\.toml$|\.lock$|\.csproj$|\.sln$|\.config$|\.props$|\.s?css$|\.html$|\.svg$|\.env|\.gitignore|\.d\.ts$|\.g\.cs$|\.designer\.cs$|generated|(^|/)(main|program|index|app\.config|app\.routes)\.(ts|cs|py|go|java)$|module\.ts$)'
}

# Durable exemptions from the list file: "<path-or-glob>  # <reason>" per line.
EXEMPT_FILE="${TEST_GUARD_EXEMPT:-scripts/test-guard.exempt}"
EXEMPT_PATTERNS=()
if [ -f "$EXEMPT_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in ''|'#'*) continue ;; esac
    pattern="${trimmed%%#*}"; pattern="${pattern%"${pattern##*[![:space:]]}"}"
    reason=""
    case "$trimmed" in *'#'*) reason="${trimmed#*#}"; reason="${reason#"${reason%%[![:space:]]*}"}" ;; esac
    if [ -z "$reason" ]; then
      echo "  ⚠️  $EXEMPT_FILE: '$pattern' has no '# reason' — ignored" >&2
      continue
    fi
    EXEMPT_PATTERNS+=("$pattern")
  done < "$EXEMPT_FILE"
fi

is_listed_exempt() {
  local p
  for p in ${EXEMPT_PATTERNS[@]+"${EXEMPT_PATTERNS[@]}"}; do
    # shellcheck disable=SC2053  # unquoted on purpose: the entry is a glob
    [[ "$1" == $p ]] && return 0
  done
  return 1
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
  if is_listed_exempt "$f"; then SKIPPED=$((SKIPPED + 1)); continue; fi
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
  echo "  Fix: write the test (see .claude/skills/test-case-design/SKILL.md), or add a"
  echo "  justified entry (path + '# reason') to $EXEMPT_FILE. Run /dp-test to generate them."
fi
echo "──────────────────────────────────────────────────────"

if [ "${STRICT:-0}" = "1" ] && [ "$N_MISSING" -gt 0 ]; then exit 1; fi
exit 0
