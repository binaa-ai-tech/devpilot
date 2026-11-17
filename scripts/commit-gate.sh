#!/usr/bin/env bash
# =============================================================================
# commit-gate.sh — the verification stamp on every commit.
#
# Every commit carries a trailer saying what proved it:
#   Verified: verify | tests | code-review | none        (comma-separated when several)
# DevPilot commands write it from what ACTUALLY ran on this exact working tree: run-tests.sh,
# verify.sh and the review each leave a stamp (`mark`), and `stamp` prints the trailer for the
# stamps whose tree fingerprint still matches. Edit a file after the tests → the stamp is gone.
#
#   commit-gate.sh mark <tests|verify|code-review> [pass|fail]   record a check on the current tree
#   commit-gate.sh stamp                                         print the Verified: trailer
#   commit-gate.sh check <commit-msg-file>                       the commit-msg hook (below)
#   commit-gate.sh mode                                          off | observe | enforce
#
# Gate mode COMMIT_GATE — environment → .devpilot/config.sh → project.config.md
# (`commit_gate:`) → observe:
#   off      no check
#   observe  (default) never blocks; what enforce would have blocked → .devpilot/logs/commit-gate.log
#   enforce  blocks a commit whose trailer is missing, invalid or `none`, unless it carries
#            `Unverified-Reason: <text>`, and blocks a FALSE claim — a check named in `Verified:`
#            with no passing stamp for this exact tree (a reason does not excuse that; say
#            `Verified: none`). Escape hatch: after 2 blocks in a row on the same branch, the
#            next attempt goes through and is logged (counter in .git/devpilot/).
# The claim check needs the stamps, so it runs on the machine that ran the checks.
# Merge, revert and fixup commits are never checked.
# List unverified changes:  git log --grep '^Verified: none'
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
STAMPS=".devpilot/logs/stamps"
GATE_LOG=".devpilot/logs/commit-gate.log"
VALID="verify tests code-review none"

# fingerprint → the tree of the working copy as it would be committed (tracked + untracked,
# .gitignore honored). docs/ and .devpilot/logs/ are left out: evidence, reports and the stamps
# themselves are written after a check and must not invalidate it.
fingerprint() {
  local idx tree
  idx=$(mktemp); rm -f "$idx"
  if [ -f "$(git rev-parse --git-dir 2>/dev/null)/index" ]; then cp "$(git rev-parse --git-dir)/index" "$idx"; fi
  GIT_INDEX_FILE="$idx" git add -A -- . ':(exclude)docs' ':(exclude).devpilot/logs' >/dev/null 2>&1
  GIT_INDEX_FILE="$idx" git rm -r -q --cached --ignore-unmatch -- docs .devpilot/logs >/dev/null 2>&1
  tree=$(GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null)
  rm -f "$idx"
  printf '%s' "$tree"
}

gate_mode() {
  local m="${COMMIT_GATE:-}"
  if [ -z "$m" ] && [ -f .devpilot/config.sh ]; then
    m=$(sed -n "s/^COMMIT_GATE=['\"]\{0,1\}\([a-z]*\).*/\1/p" .devpilot/config.sh | head -1)
  fi
  if [ -z "$m" ] && [ -f project.config.md ]; then
    m=$(grep -E '^commit_gate:' project.config.md | head -1 | sed 's/commit_gate:[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '"')
  fi
  case "$m" in off|observe|enforce) printf '%s' "$m" ;; *) printf 'observe' ;; esac
}

cmd_mark() {
  local what="${1:-}" result="${2:-pass}"
  case "$what" in tests|verify|code-review) : ;; *) echo "Usage: commit-gate.sh mark <tests|verify|code-review> [pass|fail]" >&2; exit 2 ;; esac
  case "$result" in pass|fail) : ;; *) echo "❌ result must be pass or fail" >&2; exit 2 ;; esac
  mkdir -p "$STAMPS"
  printf '%s %s %s\n' "$(fingerprint)" "$result" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$STAMPS/$what"
}

backed() {  # backed <check> <fingerprint> → 0 when that check passed on exactly this tree
  local line
  [ -f "$STAMPS/$1" ] || return 1
  line=$(head -1 "$STAMPS/$1")
  [ "${line%% *}" = "$2" ] || return 1
  case "$line" in *" pass "*) return 0 ;; esac
  return 1
}

cmd_stamp() {
  local fp what got=""
  fp=$(fingerprint)
  for what in verify tests code-review; do
    backed "$what" "$fp" && got="${got:+$got, }$what"
  done
  printf 'Verified: %s\n' "${got:-none}"
}

# unbacked <verified-value> → the claimed checks with no passing stamp on this tree (space-separated)
unbacked() {
  local fp e rest="$1" out=""
  fp=$(fingerprint)
  while [ -n "$rest" ]; do
    e="${rest%%,*}"; [ "$e" = "$rest" ] && rest="" || rest="${rest#*,}"
    e=$(printf '%s' "$e" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    [ "$e" = none ] && continue
    backed "$e" "$fp" || out="${out:+$out }$e"
  done
  printf '%s' "$out"
}

trailer() {  # trailer <msg-file> <Key> → last value of that trailer (comment lines ignored)
  grep -v '^#' "$1" | git interpret-trailers --parse 2>/dev/null | grep -i "^$2:" | tail -1 | sed 's/^[^:]*:[[:space:]]*//'
}

# valid_verified <value> → 0 when every comma-separated entry is a known check and none is
# mixed with real checks
valid_verified() {
  local v="$1" e n=0 none=0 rest
  [ -z "$v" ] && return 1
  rest="$v"
  while [ -n "$rest" ]; do
    e="${rest%%,*}"; [ "$e" = "$rest" ] && rest="" || rest="${rest#*,}"
    e=$(printf '%s' "$e" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    [ -z "$e" ] && return 1
    case " $VALID " in *" $e "*) : ;; *) return 1 ;; esac
    n=$((n + 1)); [ "$e" = none ] && none=1
  done
  [ "$none" = 1 ] && [ "$n" -gt 1 ] && return 1
  return 0
}

log_gate() {
  mkdir -p "$(dirname "$GATE_LOG")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$(git branch --show-current 2>/dev/null)" "$2" "$3" >> "$GATE_LOG"
}

cmd_check() {
  local msg="${1:-}" mode header verified reason problem counter branch n false_claim=0 missing
  [ -f "$msg" ] || { echo "Usage: commit-gate.sh check <commit-msg-file>" >&2; exit 2; }
  mode=$(gate_mode)
  [ "$mode" = off ] && return 0
  header=$(grep -v '^#' "$msg" | sed '/^[[:space:]]*$/d' | head -1)
  case "$header" in Merge*|Revert*|"fixup!"*|"squash!"*|"amend!"*) return 0 ;; esac

  verified=$(trailer "$msg" Verified)
  reason=$(trailer "$msg" Unverified-Reason)
  problem=""
  if [ -z "$verified" ]; then
    problem="no 'Verified:' trailer"
    grep -qi '^Verified:' "$msg" && problem="'Verified:' is not in the trailer block — trailers must be in the message's last paragraph, with Co-Authored-By (use: git commit --trailer \"Verified: …\")"
  elif ! valid_verified "$verified"; then problem="invalid 'Verified: $verified' (use: verify, tests, code-review or none)"
  elif [ "$(printf '%s' "$verified" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')" = none ]; then problem="'Verified: none'"
  else
    missing=$(unbacked "$verified")
    if [ -n "$missing" ]; then
      false_claim=1
      problem="'Verified: $verified' claims $(printf '%s' "$missing" | sed 's/ /, /g') — no passing run on this exact tree (bash scripts/commit-gate.sh stamp shows what ran)"
    fi
  fi

  branch=$(git branch --show-current 2>/dev/null); branch="${branch:-detached}"
  counter="$(git rev-parse --git-dir 2>/dev/null)/devpilot/commit-gate-$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '_')"

  if [ -z "$problem" ]; then rm -f "$counter"; return 0; fi

  if [ "$mode" = observe ]; then
    log_gate observe "$problem" "$header"
    return 0
  fi

  # enforce — a reason excuses an unverified commit, never a false claim
  if [ "$false_claim" = 0 ] && [ -n "$(printf '%s' "$reason" | tr -d '[:space:]')" ]; then
    log_gate allowed-unverified "$problem — reason: $reason" "$header"; rm -f "$counter"; return 0
  fi
  n=0; [ -f "$counter" ] && n=$(cat "$counter" 2>/dev/null); case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -ge 2 ]; then
    log_gate escape-hatch "$problem — let through after $n blocks in a row" "$header"
    rm -f "$counter"
    echo "⚠️  commit-gate: $problem — let through after $n blocks in a row on '$branch' (logged in $GATE_LOG)." >&2
    return 0
  fi
  mkdir -p "$(dirname "$counter")"; echo $((n + 1)) > "$counter"
  log_gate blocked "$problem" "$header"
  {
    echo "✗ commit-gate (enforce): $problem."
    [ "$false_claim" = 1 ] && echo "  Run the check on this tree (run-tests.sh / verify.sh / the review), or claim only what ran."
    echo "  Say what proved this commit, as a trailer at the end of the message:"
    echo "    Verified: tests, verify          (from: bash scripts/commit-gate.sh stamp)"
    echo "  Nothing ran? Say why:"
    echo "    Verified: none"
    echo "    Unverified-Reason: <why this commit is not verified>"
    echo "  Block $((n + 1)) of 2 on '$branch' — a third attempt goes through and is logged."
  } >&2
  return 1
}

CMD="${1:-}"; [ $# -gt 0 ] && shift
case "$CMD" in
  mark)  cmd_mark "${1:-}" "${2:-pass}" ;;
  stamp) cmd_stamp ;;
  check) cmd_check "${1:-}" ;;
  mode)  gate_mode; echo ;;
  *)     sed -n '10,13p' "$0" | sed 's/^# \{0,3\}//'; exit 2 ;;
esac
