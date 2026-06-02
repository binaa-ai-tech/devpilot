#!/usr/bin/env bash
# =============================================================================
# scope.sh "<task description>" — rank the files most relevant to a task.
#
# Reads docs/project-index.md (regenerates it if missing) and prints the top
# candidate files ranked by keyword overlap with the task. Agents call this to
# retrieve a handful of files to read instead of scanning the whole codebase.
#
#   bash scripts/scope.sh "add a logout button to the header"
#   TOPN=12 bash scripts/scope.sh "fix order total rounding"
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK="${*:-}"
[ -z "$TASK" ] && { echo "Usage: scope.sh \"<task description>\"" >&2; exit 1; }

INDEX="$ROOT/docs/project-index.md"
[ -f "$INDEX" ] || bash "$ROOT/scripts/generate-project-index.sh" >/dev/null 2>&1 || true
[ -f "$INDEX" ] || { echo "No project index available (run generate-project-index.sh)." >&2; exit 1; }

TOPN="${TOPN:-8}"
STOP=" the a an and or of to for in on with is are be by from as at this that add new fix update create change make use using support need want should "

# Tokens from the task: lowercase, >=3 chars, de-duped, stopwords removed.
RAW=$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | awk 'length($0)>=3' | sort -u)
TOKENS=""
for t in $RAW; do case "$STOP" in *" $t "*) ;; *) TOKENS="$TOKENS $t" ;; esac; done
TOKENS="${TOKENS# }"
[ -z "$TOKENS" ] && { echo "(task had no usable keywords — read docs/project-index.md directly)"; exit 0; }

echo "🔎 scope for: $TASK"
echo "   keywords: $TOKENS"
echo ""

awk -v toks="$TOKENS" '
  /^[ \t]+/ && /[A-Za-z]/ && !/^[ \t]*#/ {
    line = tolower($0); score = 0; hits = "";
    n = split(toks, T, " ");
    for (i = 1; i <= n; i++) {
      if (T[i] != "" && index(line, T[i]) > 0) { score++; hits = hits " " T[i] }
    }
    if (score > 0) { printf "%d\t%s\t%s\n", score, $0, hits }
  }
' "$INDEX" | sort -rn -k1,1 | head -n "$TOPN" | \
while IFS=$'\t' read -r score rest hits; do
  path=$(echo "$rest" | sed 's/^[[:space:]]*//')
  printf '  [%d] %s\n' "$score" "$path"
  printf '       ↳ matched:%s\n' "$hits"
done

echo ""
echo "(ranked by keyword overlap — read these first, not the whole tree)"
