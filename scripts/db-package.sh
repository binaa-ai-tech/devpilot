#!/usr/bin/env bash
# =============================================================================
# db-package.sh — the database part of a release, for DBAs and change boards.
#
#   bash scripts/db-package.sh <out-dir> [--project <migrations.csproj>] [--startup <api.csproj>]
#
# Writes (EF Core, needs the dotnet-ef tool):
#   migrations.sql   idempotent — safe to run on any environment, any number of times
#   rollback.sql     this release's schema → the previous release's (only when the release adds
#                    migrations; review it: a down-migration can drop data)
#   migrations.txt   the migrations this release adds, vs the previous v* tag
#   README.md        how to apply and roll back
# The previous release = the highest v* tag below the current version, so CI needs
# the tags (the generated pipelines fetch full history + tags).
# =============================================================================
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

OUTD="${1:?Usage: db-package.sh <out-dir> [--project <csproj>] [--startup <csproj>]}"; shift
PROJ=""; STARTUP=""
while [ $# -gt 0 ]; do case "$1" in --project) PROJ="${2:-}"; shift 2 ;; --startup) STARTUP="${2:-}"; shift 2 ;; *) shift ;; esac; done

if [ -n "$PROJ" ]; then MIG_DIR="$(dirname "$PROJ")/Migrations"
else MIG_DIR=$(find . -maxdepth 6 -type d -name Migrations -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | sed 's#^\./##'); fi
[ -n "$MIG_DIR" ] && [ -d "$MIG_DIR" ] || { echo "ℹ️  no EF Core Migrations folder — no database package"; exit 0; }
command -v dotnet >/dev/null 2>&1 || { echo "❌ dotnet not found" >&2; exit 1; }

EF=(dotnet ef)
ARGS=(); [ -n "$PROJ" ] && ARGS+=(--project "$PROJ"); [ -n "$STARTUP" ] && ARGS+=(--startup-project "$STARTUP")

names_at() {  # migration names (timestamp_Name) at a ref — Designer/snapshot files excluded
  git ls-tree -r --name-only "$1" -- "$MIG_DIR" 2>/dev/null \
    | sed -nE 's#.*/([0-9]{14}_[^./]+)\.cs$#\1#p' | sort
}
# Previous release = the highest v* tag BELOW this build's version. Chosen by version,
# not reachability: git-flow tags the merge commit on main, which develop/release
# branches never contain.
CUR_V=$(bash "$ROOT/scripts/version.sh" current 2>/dev/null || echo 0.0.0)
PREV_TAG=$( { git tag -l 'v[0-9]*' 2>/dev/null | sed 's/^v//'; echo "$CUR_V"; } | sort -t. -k1,1n -k2,2n -k3,3n -u \
  | awk -v c="$CUR_V" '$0 == c { print p; exit } { p = $0 }')
[ -n "$PREV_TAG" ] && PREV_TAG="v$PREV_TAG"
CUR=$(names_at HEAD); PREV=""; [ -n "$PREV_TAG" ] && PREV=$(names_at "$PREV_TAG")
NEW=$(comm -13 <(printf '%s\n' "$PREV" | sed '/^$/d') <(printf '%s\n' "$CUR" | sed '/^$/d'))
CUR_LAST=$(printf '%s\n' "$CUR" | sed '/^$/d' | tail -1)
PREV_LAST=$(printf '%s\n' "$PREV" | sed '/^$/d' | tail -1)

mkdir -p "$OUTD"
"${EF[@]}" migrations script --idempotent ${ARGS[@]+"${ARGS[@]}"} --output "$OUTD/migrations.sql" \
  || { echo "❌ could not generate migrations.sql" >&2; exit 1; }

{
  echo "# Migrations in this release (since ${PREV_TAG:-the first release})"
  if [ -n "$NEW" ]; then printf '%s\n' "$NEW" | sed 's/^/- /'; else echo "- none — no schema change"; fi
} > "$OUTD/migrations.txt"

ROLLBACK="none"
if [ -n "$NEW" ] && [ -n "$CUR_LAST" ]; then
  "${EF[@]}" migrations script "$CUR_LAST" "${PREV_LAST:-0}" ${ARGS[@]+"${ARGS[@]}"} --output "$OUTD/rollback.sql" \
    || { echo "❌ could not generate rollback.sql" >&2; exit 1; }
  ROLLBACK="rollback.sql → ${PREV_LAST:-empty database}"
fi

cat > "$OUTD/README.md" <<EOF
# Database package — $(bash "$ROOT/scripts/version.sh" current 2>/dev/null || echo "this release")

| File | Use |
|------|-----|
| migrations.sql | Apply before (or with) the app deploy. Idempotent: already-applied migrations are skipped. |
| rollback.sql | ${ROLLBACK} — only with the app rollback; review first, a down-migration can drop data. |
| migrations.txt | What this release changes (vs ${PREV_TAG:-no previous release}). |

Apply: \`sqlcmd -S <server> -d <database> -i migrations.sql -b\` (or your deploy/deploy.sh does it).
EOF
echo "✅ database package → $OUTD ($(printf '%s\n' "$NEW" | sed '/^$/d' | wc -l | tr -d ' ') new migration(s) since ${PREV_TAG:-start}; rollback: $ROLLBACK)"
