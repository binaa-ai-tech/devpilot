#!/usr/bin/env bash
# =============================================================================
# rules-guard.sh — keep the checks that judge a change out of that change's reach.
#
# The rules, skills, review prompts, gate scripts and CI workflows decide whether a
# change is good. A change that edits them is grading itself, so:
#   - a review reads them from the base branch, never from the working tree (show)
#   - a diff that touches them is called out for human review (touched)
#   - during /dp-build and /dp-deliver the PreToolUse hook blocks edits to them (lock)
#
#   rules-guard.sh list                       the protected path patterns
#   rules-guard.sh match <path>               exit 0 when <path> is protected
#   rules-guard.sh touched [base]             protected files this branch changed; exit 1 when any
#   rules-guard.sh show <path> [base]         <path> as it is on origin/<base> — the trusted copy
#   rules-guard.sh lock <KEY…> [--tooling]    build guard on for the current branch
#   rules-guard.sh unlock                     build guard off
#   rules-guard.sh guard <path>               hook check: exit 2 + reason when the edit is blocked
#   rules-guard.sh status                     is a build guard active?
#
# --tooling: the Story itself targets DevPilot tooling ("Tooling: yes" in its item brief) —
# edits are allowed, and the review still flags them (touched).
# Patterns are bash globs, so "*" also crosses "/". Extra project paths: one glob per line
# in .devpilot/protected-paths (read from the base branch when it exists there).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
LOCK=".devpilot/.rules-lock"
EXTRA=".devpilot/protected-paths"
BANNER="⚠️ This change edits the checks that judge it — human review required."

PROTECTED=".claude/skills/*
.claude/commands/*
.claude/agents/*
.claude/settings.json
.devpilot/rules/*
.devpilot/rules.md
.devpilot/reliability-checklist.md
.devpilot/prompts/*
.devpilot/protected-paths
CLAUDE.md
scripts/test-guard.sh
scripts/test-guard.exempt
scripts/rules-guard.sh
scripts/scope-hook.sh
scripts/verify.sh
scripts/reliability.sh
scripts/install-git-hooks.sh
.github/workflows/*
.github/CODEOWNERS"

base_branch() {
  local b; b=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  printf '%s' "${b:-develop}"
}

# base_ref [base] → origin/<base> when it exists, else <base>, else empty
base_ref() {
  local b="${1:-$(base_branch)}"
  if git rev-parse --verify --quiet "origin/$b" >/dev/null 2>&1; then printf 'origin/%s' "$b"
  elif git rev-parse --verify --quiet "$b" >/dev/null 2>&1; then printf '%s' "$b"; fi
}

patterns() {
  local ref
  printf '%s\n' "$PROTECTED"
  ref=$(base_ref)
  if [ -n "$ref" ] && git cat-file -e "$ref:$EXTRA" 2>/dev/null; then git show "$ref:$EXTRA" 2>/dev/null
  elif [ -f "$EXTRA" ]; then cat "$EXTRA"; fi | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//' | grep -v '^$' || true
}

# rel <path> → repo-relative (hooks pass absolute paths)
rel() {
  local p="$1" d
  case "$p" in
    "$ROOT"/*) : ;;
    /*) d=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) && p="$d/$(basename "$p")" ;;   # symlinked checkout (/var → /private/var)
  esac
  case "$p" in "$ROOT"/*) p="${p#"$ROOT"/}" ;; esac
  printf '%s' "${p#./}"
}

is_protected() {
  local f g; f=$(rel "$1")
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    # shellcheck disable=SC2053  # unquoted on purpose: the entry is a glob
    [[ "$f" == $g ]] && return 0
  done <<EOF
$(patterns)
EOF
  return 1
}

lock_field() { [ -f "$LOCK" ] && sed -n "s/^$1=//p" "$LOCK" | head -1; }

lock_active() {
  [ -f "$LOCK" ] || return 1
  [ "$(lock_field branch)" = "$(git branch --show-current 2>/dev/null)" ]
}

CMD="${1:-}"; [ $# -gt 0 ] && shift
case "$CMD" in
  list)
    patterns ;;

  match)
    [ -n "${1:-}" ] || { echo "Usage: rules-guard.sh match <path>" >&2; exit 2; }
    is_protected "$1" ;;

  touched)
    REF=$(base_ref "${1:-}")
    CHANGED=$( { [ -n "$REF" ] && git diff --name-only "$REF"...HEAD 2>/dev/null
                 git diff --name-only HEAD 2>/dev/null
                 git ls-files --others --exclude-standard 2>/dev/null; } | sort -u | grep -v '^$' || true)
    HITS=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      is_protected "$f" && HITS="${HITS}  - $f
"
    done <<EOF
$CHANGED
EOF
    if [ -z "$HITS" ]; then echo "✅ rules-guard: no rule, skill, gate script or workflow changed (vs ${REF:-working tree})"; exit 0; fi
    echo "$BANNER"
    echo "Changed checks (vs ${REF:-working tree}) — review them against the base copy (rules-guard.sh show <path>):"
    printf '%s' "$HITS"
    exit 1 ;;

  show)
    P="${1:-}"; [ -n "$P" ] || { echo "Usage: rules-guard.sh show <path> [base]" >&2; exit 2; }
    P=$(rel "$P"); REF=$(base_ref "${2:-}")
    [ -n "$REF" ] || { echo "❌ rules-guard: base branch '${2:-$(base_branch)}' not found — fetch it: git fetch origin" >&2; exit 2; }
    if git cat-file -e "$REF:$P" 2>/dev/null; then git show "$REF:$P"
    else
      echo "❌ rules-guard: $P does not exist on $REF — it is new on this branch, so it is not yet a trusted rule" >&2
      exit 1
    fi ;;

  lock)
    KEYS=""; TOOLING="no"
    while [ $# -gt 0 ]; do
      case "$1" in --tooling) TOOLING="yes" ;; *) KEYS="${KEYS:+$KEYS }$1" ;; esac
      shift
    done
    [ -n "$KEYS" ] || { echo "Usage: rules-guard.sh lock <KEY…> [--tooling]" >&2; exit 2; }
    mkdir -p .devpilot
    printf 'branch=%s\nkeys=%s\ntooling=%s\n' "$(git branch --show-current 2>/dev/null)" "$KEYS" "$TOOLING" > "$LOCK"
    if [ "$TOOLING" = "yes" ]; then echo "✅ rules-guard: build guard on for $KEYS — tooling Story, rule edits allowed (the review will flag them)"
    else echo "✅ rules-guard: build guard on for $KEYS — edits to rules, skills, gate scripts and workflows are blocked"; fi ;;

  unlock)
    rm -f "$LOCK"; echo "✅ rules-guard: build guard off" ;;

  guard)
    [ -n "${1:-}" ] || exit 0
    lock_active || exit 0
    [ "$(lock_field tooling)" = "yes" ] && exit 0
    is_protected "$1" || exit 0
    echo "rules-guard: '$(rel "$1")' is one of the checks that judge this change — blocked while building $(lock_field keys)." >&2
    echo "  A build may not edit its own rules, skills, gate scripts or CI workflows." >&2
    echo "  Story really about DevPilot tooling? Put 'Tooling: yes' in its brief, then: bash scripts/rules-guard.sh lock $(lock_field keys) --tooling" >&2
    echo "  Build finished or abandoned? bash scripts/rules-guard.sh unlock" >&2
    exit 2 ;;

  status)
    if lock_active; then echo "build guard ON — branch $(lock_field branch) · keys $(lock_field keys) · tooling $(lock_field tooling)"
    elif [ -f "$LOCK" ]; then echo "build guard idle — lock belongs to branch $(lock_field branch) (remove: rules-guard.sh unlock)"
    else echo "build guard off"; fi ;;

  *)
    sed -n '10,17p' "$0" | sed 's/^# \{0,3\}//'; exit 2 ;;
esac
