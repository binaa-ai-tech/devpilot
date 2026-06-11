#!/usr/bin/env bash
# =============================================================================
# scope.sh — rank the files most relevant to a task, WITHOUT loading the index
# into agent context. Greps the map + detail shards (docs/index/*.md) and
# prints the top candidates. The token contract: agents read the small map +
# this output — never the shards.
#
#   bash scripts/scope.sh "add a logout button to the header"
#   bash scripts/scope.sh --save csv-export "add CSV export to orders"
#   TOPN=12 bash scripts/scope.sh "fix order total rounding"
#
# --save <slug> writes docs/tasks/<slug>-scope.md so every later phase (lead,
# devs, QA) REUSES the scope instead of re-deriving it. A cached scope newer
# than the index is returned as-is (cache hit).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

SLUG=""
if [ "${1:-}" = "--save" ]; then
  SLUG="${2:-}"; shift 2 || true
  [ -z "$SLUG" ] && { echo "Usage: scope.sh --save <slug> \"<task>\"" >&2; exit 1; }
fi
TASK="${*:-}"
[ -z "$TASK" ] && { echo "Usage: scope.sh [--save <slug>] \"<task description>\"" >&2; exit 1; }

INDEX="$ROOT/docs/project-index.md"
SHARD_DIR="$ROOT/docs/index"
CACHE="$ROOT/docs/tasks/${SLUG}-scope.md"

# Cache hit: saved scope exists and is newer than the index → reuse, zero work.
if [ -n "$SLUG" ] && [ -f "$CACHE" ] && [ -f "$INDEX" ] && [ "$CACHE" -nt "$INDEX" ]; then
  echo "♻️  cached scope (docs/tasks/${SLUG}-scope.md) — newer than the index, reusing:"
  cat "$CACHE"
  exit 0
fi

# Keep the index fresh: build it when missing; when devpilot manages it (a
# .state signature exists) the call is hash-gated — a free no-op unless the
# repo changed. A hand-maintained index (no .state) is left untouched.
if [ ! -f "$INDEX" ] || [ -f "$SHARD_DIR/.state" ]; then
  bash "$ROOT/scripts/generate-project-index.sh" >/dev/null 2>&1 || true
fi
[ -f "$INDEX" ] || { echo "No project index available (run generate-project-index.sh)." >&2; exit 1; }

# Search surface = map + shards (shards hold the per-file detail).
SOURCES="$INDEX"
if [ -d "$SHARD_DIR" ]; then
  for sh in "$SHARD_DIR"/*.md; do [ -f "$sh" ] && SOURCES="$SOURCES $sh"; done
fi

TOPN="${TOPN:-8}"
STOP=" the a an and or of to for in on with is are be by from as at this that add new fix update create change make use using support need want should "

# Tokens from the task: lowercase, >=3 chars, de-duped, stopwords removed.
RAW=$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | awk 'length($0)>=3' | sort -u)
TOKENS=""
for t in $RAW; do case "$STOP" in *" $t "*) ;; *) TOKENS="$TOKENS $t" ;; esac; done
TOKENS="${TOKENS# }"
[ -z "$TOKENS" ] && { echo "(task had no usable keywords — read the index map and pick by area)"; exit 0; }

emit() {
  echo "🔎 scope for: $TASK"
  echo "   keywords: $TOKENS"
  echo ""
  # shellcheck disable=SC2086
  awk -v toks="$TOKENS" '
    /^[ \t]+/ && /[A-Za-z]/ && !/^[ \t]*#/ {
      line = tolower($0); score = 0; hits = "";
      n = split(toks, T, " ");
      for (i = 1; i <= n; i++) {
        if (T[i] != "" && index(line, T[i]) > 0) { score++; hits = hits " " T[i] }
      }
      if (score > 0) { printf "%d\t%s\t%s\n", score, $0, hits }
    }
  ' $SOURCES | sort -rn -k1,1 | head -n "$TOPN" | \
  while IFS=$'\t' read -r score rest hits; do
    path=$(echo "$rest" | sed 's/^[[:space:]]*//')
    printf '  [%d] %s\n' "$score" "$path"
    printf '       ↳ matched:%s\n' "$hits"
  done
  echo ""
  echo "(ranked by keyword overlap — read these files only, never the shards/tree)"
}

if [ -n "$SLUG" ]; then
  mkdir -p "$ROOT/docs/tasks"
  emit | tee "$CACHE"
  echo "💾 scope saved → docs/tasks/${SLUG}-scope.md (later phases reuse this)"
else
  emit
fi
