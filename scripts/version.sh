#!/usr/bin/env bash
# =============================================================================
# version.sh — SemVer for the whole repo (Angular package.json + .NET projects).
#
#   current [--ref <git-ref>]          version on the working tree (or on a ref)
#   next <major|minor|patch> [--ref]   the version a bump would produce
#   bump <major|minor|patch|X.Y.Z> [--ref <git-ref>]
#                                      write it to every version file, print it.
#                                      --ref origin/develop bumps FROM develop's
#                                      version, so parallel PRs never skip or reuse one
#   level <intent...>                  feature|enhancement|requirement|task → minor,
#                                      bug|issue|fix|chore|docs → patch, breaking → major
#                                      (several intents → the highest)
#   files                              the files that carry the version
#
# Source of truth, first found: VERSION · Directory.Build.props · package.json
# (root, then ≤3 levels deep) · *.csproj <Version>. No version anywhere → 0.0.0,
# and the first bump creates a VERSION file.
# =============================================================================
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

SEMVER='^[0-9]+\.[0-9]+\.[0-9]+$'

files() {
  [ -f VERSION ] && echo VERSION
  [ -f Directory.Build.props ] && grep -q '<Version>' Directory.Build.props && echo Directory.Build.props
  find . -maxdepth 3 -name package.json -not -path '*/node_modules/*' 2>/dev/null | sed 's#^\./##' | sort \
    | while read -r f; do grep -qE '^[[:space:]]{2}"version"[[:space:]]*:' "$f" && echo "$f"; done
  find . -maxdepth 4 -name '*.csproj' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | sed 's#^\./##' | sort \
    | while read -r f; do grep -q '<Version>' "$f" && echo "$f"; done
  return 0
}

read_version() {  # read_version <file-content-on-stdin> <file-name>
  case "$1" in
    VERSION)                 head -1 | tr -d '[:space:]' ;;
    *.props|*.csproj)        sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' | head -1 ;;
    *package.json)           sed -nE 's/^[[:space:]]{2}"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1 ;;
  esac
}

current() {
  local ref="${1:-}" f v=""
  f=$(files | head -1)
  if [ -n "$f" ]; then
    if [ -n "$ref" ]; then v=$(git show "$ref:$f" 2>/dev/null | read_version "$f")
    else v=$(read_version "$f" < "$f"); fi
  fi
  if [ -z "$v" ]; then
    v=$(git tag -l 'v[0-9]*' --sort=-version:refname 2>/dev/null | head -1 | sed 's/^v//')
  fi
  v="${v%%-*}"; v="${v%%+*}"
  [[ "$v" =~ $SEMVER ]] || v="0.0.0"
  echo "$v"
}

next() {
  local level="$1" v="$2" ma mi pa
  IFS=. read -r ma mi pa <<< "$v"
  case "$level" in
    major) echo "$((ma + 1)).0.0" ;;
    minor) echo "$ma.$((mi + 1)).0" ;;
    patch) echo "$ma.$mi.$((pa + 1))" ;;
    *) [[ "$level" =~ $SEMVER ]] && echo "$level" || { echo "❌ level must be major|minor|patch|X.Y.Z" >&2; return 1; } ;;
  esac
}

write_version() {
  local new="$1" f tmp any=0
  for f in $(files); do
    tmp=$(mktemp)
    case "$f" in
      VERSION) echo "$new" > "$tmp" ;;
      *.props|*.csproj) sed "s:<Version>[^<]*</Version>:<Version>$new</Version>:" "$f" > "$tmp" ;;
      *package.json) awk -v v="$new" '!d && /^  "version"[[:space:]]*:/ { sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" v "\""); d = 1 } { print }' "$f" > "$tmp" ;;
    esac
    cat "$tmp" > "$f"; rm -f "$tmp"; any=1
    echo "  ✎ $f" >&2
    # Keep the npm lockfile's root version in step (first two "version" keys = root + packages[""]).
    if [ "${f##*/}" = "package.json" ] && [ -f "${f%package.json}package-lock.json" ]; then
      local lock="${f%package.json}package-lock.json"
      tmp=$(mktemp)
      awk -v v="$new" '
        function setv() { sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" v "\"") }
        !r && /^  "version"[[:space:]]*:/        { setv(); r = 1 }
        /^    "": [{]/                           { p = 1 }
        p == 1 && /^      "version"[[:space:]]*:/ { setv(); p = 2 }
        { print }' "$lock" > "$tmp"
      cat "$tmp" > "$lock"; rm -f "$tmp"; echo "  ✎ $lock" >&2
    fi
  done
  if [ "$any" = 0 ]; then echo "$new" > VERSION; echo "  ✎ VERSION (created)" >&2; fi
}

REF=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in --ref) REF="${2:-}"; shift 2 ;; *) ARGS+=("$1"); shift ;; esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

cmd="${1:-current}"; shift || true
case "$cmd" in
  current) current "$REF" ;;
  files)   files ;;
  next)    next "${1:?Usage: version.sh next <major|minor|patch>}" "$(current "$REF")" ;;
  bump)
    NEW=$(next "${1:?Usage: version.sh bump <major|minor|patch|X.Y.Z> [--ref <git-ref>]}" "$(current "$REF")") || exit 1
    write_version "$NEW"
    echo "$NEW"
    ;;
  level)
    L="patch"
    for i in "$@"; do
      case "$(echo "$i" | tr '[:upper:]' '[:lower:]')" in
        breaking|major) L="major" ;;
        feature|enhancement|requirement|task|story|feat) [ "$L" = "major" ] || L="minor" ;;
      esac
    done
    echo "$L"
    ;;
  *) sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
