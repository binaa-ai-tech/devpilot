#!/usr/bin/env bash
# =============================================================================
# reliability.sh — run only the reliability-checklist items the diff triggers.
#
# The checklist (.devpilot/reliability-checklist.md) is read from the BASE branch, so a
# change cannot edit the questions it is asked (rules-guard.sh). Each item has a trigger
# readable from a diff — Paths (globs on changed files) and/or Code (an extended regex,
# case-insensitive, on added or removed lines) — a Check question and an Origin.
#
#   reliability.sh match [base]        items the diff triggers, with what triggered them
#   reliability.sh list                every item: id · title · origin
#   reliability.sh validate [file]     every item has a trigger, a check and an origin
#
# Exit: 0 ok · 1 validate found problems · 2 usage / no checklist
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
LIST=".devpilot/reliability-checklist.md"

base_branch() {
  local b; b=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  printf '%s' "${b:-develop}"
}

base_ref() {
  local b="${1:-$(base_branch)}"
  if git rev-parse --verify --quiet "origin/$b" >/dev/null 2>&1; then printf 'origin/%s' "$b"
  elif git rev-parse --verify --quiet "$b" >/dev/null 2>&1; then printf '%s' "$b"; fi
}

# checklist_text [base] → the trusted copy (base branch), else the working tree with a note
SOURCE=""
checklist_text() {
  local ref; ref=$(base_ref "${1:-}")
  if [ -n "$ref" ] && git cat-file -e "$ref:$LIST" 2>/dev/null; then
    SOURCE="$ref:$LIST"; git show "$ref:$LIST"
  elif [ -f "$LIST" ]; then
    SOURCE="$LIST (working tree — not on ${ref:-the base branch} yet, so not a trusted copy)"; cat "$LIST"
  fi
}

# items <file> → id US title US paths US code US check US origin per item (US = \037, so an
# empty field survives `read` — a tab would collapse as whitespace)
US=$'\037'
items() {
  awk '
    function flush() { if (id != "") printf "%s\037%s\037%s\037%s\037%s\037%s\n", id, title, paths, code, check, origin }
    function val(s) { sub(/^- [A-Za-z]+:[[:space:]]*/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^## / { flush(); line = $0; sub(/^## +/, "", line); id = line; sub(/[[:space:]].*$/, "", id)
             title = line; sub(/^[^[:space:]]+[[:space:]]*(·|-|—|:)?[[:space:]]*/, "", title)
             paths = ""; code = ""; check = ""; origin = ""; next }
    /^- Paths:/  { paths = val($0) }
    /^- Code:/   { code = val($0); gsub(/^`|`$/, "", code) }
    /^- Check:/  { check = val($0) }
    /^- Origin:/ { origin = val($0) }
    END { flush() }
  ' "$1"
}

changed_files() {
  local ref="$1"
  { [ -n "$ref" ] && git diff --name-only "$ref"...HEAD 2>/dev/null
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null; } | sort -u | grep -v '^$' || true
}

# changed_lines <ref> → "path<TAB>+|-line" for every added/removed line (untracked files: every line)
changed_lines() {
  local ref="$1" f
  { [ -n "$ref" ] && git diff -U0 --no-color "$ref"...HEAD 2>/dev/null
    git diff -U0 --no-color HEAD 2>/dev/null; } | awk '
      /^\+\+\+ / { f = $2; sub(/^b\//, "", f); next }
      /^--- /    { next }
      /^[+-]/    { if (f != "" && f != "/dev/null") print f "\t" $0 }'
  git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
    [ -f "$f" ] && grep -Iq . "$f" 2>/dev/null && sed "s|^|$f	+|" "$f"
  done
}

glob_hit() {  # glob_hit <file> "<glob>, <glob>"
  local f="$1" g rest="$2"
  while [ -n "$rest" ]; do
    g="${rest%%,*}"; [ "$g" = "$rest" ] && rest="" || rest="${rest#*,}"
    g="${g//\`/}"; g="${g#"${g%%[![:space:]]*}"}"; g="${g%"${g##*[![:space:]]}"}"
    [ -z "$g" ] && continue
    # shellcheck disable=SC2053  # unquoted on purpose: the entry is a glob
    [[ "$f" == $g ]] && return 0
    # a pattern without "/" also matches the basename anywhere (*.sql, package.json)
    # shellcheck disable=SC2053
    case "$g" in */*) : ;; *) [[ "$(basename "$f")" == $g ]] && return 0 ;; esac
  done
  return 1
}

cmd_match() {
  local ref tmp files lines n=0 id title paths code check origin hit why f l
  ref=$(base_ref "${1:-}")
  tmp=$(mktemp)
  checklist_text "${1:-}" > "$tmp"
  [ -s "$tmp" ] || { rm -f "$tmp"; echo "❌ no $LIST on the base branch or in the working tree — install it: bash install.sh --update" >&2; return 2; }
  files=$(changed_files "$ref"); lines=$(changed_lines "$ref")
  echo "── reliability checklist (vs ${ref:-working tree}) ─────────"
  echo "source: $SOURCE"
  while IFS="$US" read -r id title paths code check origin; do
    [ -z "$id" ] && continue
    hit=""; why=""
    if [ -n "$paths" ]; then
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        if glob_hit "$f" "$paths"; then hit=1; why="file \`$f\`"; break; fi
      done <<EOF
$files
EOF
    fi
    if [ -z "$hit" ] && [ -n "$code" ] && [ -n "$lines" ]; then
      l=$(printf '%s\n' "$lines" | grep -iE -m1 -- "$code" 2>/dev/null || true)
      [ -n "$l" ] && { hit=1; why="line \`$(printf '%s' "$l" | cut -f1)\`: $(printf '%s' "$l" | cut -f2- | cut -c1-100)"; }
    fi
    [ -z "$hit" ] && continue
    n=$((n + 1))
    echo ""
    echo "### $id · $title   (origin: ${origin:-?})"
    echo "- Triggered by: $why"
    echo "- Check: $check"
    echo "- Evidence: <answer with a test name, a command + its output, or file:line>"
  done < <(items "$tmp")
  rm -f "$tmp"
  echo ""
  if [ "$n" = 0 ]; then echo "✅ no checklist item triggered by this diff"
  else echo "$n item(s) triggered — answer each with evidence in the review report."; fi
  echo "──────────────────────────────────────────────────────"
}

cmd_list() {
  local tmp; tmp=$(mktemp)
  checklist_text > "$tmp"
  [ -s "$tmp" ] || { rm -f "$tmp"; echo "❌ no $LIST" >&2; return 2; }
  items "$tmp" | awk -F'\037' '{ printf "%s\t%s\t%s\n", $1, $2, $6 }'
  rm -f "$tmp"
}

cmd_validate() {
  local file="${1:-$LIST}" bad=0 n=0 id title paths code check origin seen=" "
  [ -f "$file" ] || { echo "❌ $file not found" >&2; return 2; }
  while IFS="$US" read -r id title paths code check origin; do
    [ -z "$id" ] && continue
    n=$((n + 1))
    case "$seen" in *" $id "*) echo "  ❌ $id: duplicate id"; bad=1 ;; esac
    seen="$seen$id "
    [ -z "$paths" ] && [ -z "$code" ] && { echo "  ❌ $id: no trigger (Paths or Code)"; bad=1; }
    [ -z "$check" ]  && { echo "  ❌ $id: no Check question"; bad=1; }
    [ -z "$origin" ] && { echo "  ❌ $id: no Origin (seed, an incident or a PR)"; bad=1; }
    if [ -n "$code" ]; then
      printf '' | grep -iE -- "$code" >/dev/null 2>&1; [ $? -eq 2 ] && { echo "  ❌ $id: Code is not a valid extended regex"; bad=1; }
    fi
  done < <(items "$file")
  [ "$n" = 0 ] && { echo "  ❌ no items in $file"; bad=1; }
  [ "$bad" = 0 ] && echo "✅ $file: $n item(s), each with a trigger, a check and an origin"
  return "$bad"
}

CMD="${1:-}"; [ $# -gt 0 ] && shift
case "$CMD" in
  match)    cmd_match "${1:-}" ;;
  list)     cmd_list ;;
  validate) cmd_validate "${1:-}" ;;
  *)        sed -n '10,12p' "$0" | sed 's/^# \{0,3\}//'; exit 2 ;;
esac
