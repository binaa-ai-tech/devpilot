#!/usr/bin/env bash
# =============================================================================
# changelog.sh — release notes without merge conflicts.
#
#   changelog.sh add <KEY> <feat|fix|perf|refactor|docs|chore> "<summary>" [link]
#       one entry file per item: docs/changes/<type>-<KEY>.md — every PR adds its own
#       file, so parallel deliveries never conflict on CHANGELOG.md
#   changelog.sh preview            the unreleased entries, grouped
#   changelog.sh <version>          release: turn the entries into a "## v<version>" section
#                                   of CHANGELOG.md and remove them (falls back to the
#                                   conventional commits since the last tag when there are none)
#   changelog.sh keys <version>     the item keys in that version's section (release notes)
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
OUT="$ROOT/CHANGELOG.md"
DIRC="$ROOT/docs/changes"
DATE=$(date '+%Y-%m-%d')

title_of() {
  case "$1" in
    feat) echo "Features" ;; fix) echo "Fixes" ;; perf) echo "Performance" ;;
    refactor) echo "Refactors" ;; docs) echo "Documentation" ;; *) echo "Other changes" ;;
  esac
}

from_entries() {
  local t f any=""
  for t in feat fix perf refactor docs chore; do
    any=""
    for f in "$DIRC/$t"-*.md; do
      [ -f "$f" ] || continue
      [ -z "$any" ] && { printf '\n### %s\n' "$(title_of "$t")"; any=1; }
      cat "$f"
    done
  done
}

from_commits() {
  local last range t lines
  last=$(git tag -l 'v[0-9]*' --sort=-version:refname 2>/dev/null | head -1)
  range="HEAD"; [ -n "$last" ] && range="${last}..HEAD"
  for t in feat fix perf refactor docs; do
    lines=$(git log "$range" --no-merges --pretty='%s' 2>/dev/null \
      | grep -E "^${t}(\(.+\))?!?:" | sed -E "s/^${t}(\(.+\))?!?:[[:space:]]*//" | sed 's/^/- /')
    [ -n "$lines" ] && printf '\n### %s\n%s\n' "$(title_of "$t")" "$lines"
  done
}

cmd="${1:-}"
case "$cmd" in
  add)
    KEY="${2:?Usage: changelog.sh add <KEY> <type> \"<summary>\" [link]}"; TYPE="${3:-feat}"; SUM="${4:?summary}"; LINK="${5:-}"
    case "$TYPE" in feat|fix|perf|refactor|docs|chore) ;; *) TYPE="chore" ;; esac
    mkdir -p "$DIRC"
    rm -f "$DIRC"/*-"$KEY".md                       # re-adding replaces (type may change)
    if [ -n "$LINK" ]; then echo "- $SUM ([$KEY]($LINK))" > "$DIRC/$TYPE-$KEY.md"
    else echo "- $SUM ($KEY)" > "$DIRC/$TYPE-$KEY.md"; fi
    echo "docs/changes/$TYPE-$KEY.md"
    ;;
  preview)
    BODY=$(from_entries); echo "## Unreleased${BODY:+$'\n'$BODY}"
    [ -z "$BODY" ] && echo "(no entries in docs/changes/)"
    ;;
  keys)
    V="${2:?Usage: changelog.sh keys <version>}"
    [ -f "$OUT" ] && awk -v v="## v$V " 'index($0, v) == 1 { f = 1; next } f && /^## / { exit } f' "$OUT" \
      | grep -oE '\[?[A-Z][A-Z0-9_]*-[0-9]+\]?' | tr -d '[]' | sort -u
    ;;
  ""|-h|--help)
    sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  *)
    VERSION="$cmd"
    BODY=$(from_entries); SRC="entries"
    if [ -z "$BODY" ]; then BODY=$(from_commits); SRC="commits"; fi
    [ -z "$BODY" ] && BODY=$'\n- (no changes recorded)'
    NEW=$(printf '## v%s — %s\n%s\n' "$VERSION" "$DATE" "$BODY")
    TMP=$(mktemp)
    if [ -f "$OUT" ]; then
      { printf '# Changelog\n\n%s\n\n' "$NEW"; sed '1{/^# Changelog/d;}' "$OUT" | sed '/./,$!d'; } > "$TMP"
    else
      printf '# Changelog\n\n%s\n' "$NEW" > "$TMP"
    fi
    mv "$TMP" "$OUT"
    if [ "$SRC" = "entries" ]; then
      git rm -q --ignore-unmatch "$DIRC"/*.md >/dev/null 2>&1 || true
      rm -f "$DIRC"/*.md
    fi
    echo "✅ CHANGELOG.md — v$VERSION from $SRC"
    ;;
esac
