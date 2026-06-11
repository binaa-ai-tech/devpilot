#!/usr/bin/env bash
# =============================================================================
# update-org.sh — roll the latest devpilot into EVERY repo of a GitHub org.
#
#   bash scripts/update-org.sh <org>                      # open a PR per repo
#   bash scripts/update-org.sh <org> --merge              # PR + merge when green
#   bash scripts/update-org.sh <org> --repos a,b,c        # only these repos
#   bash scripts/update-org.sh <org> --install-missing    # fresh --defaults install
#                                                         # on repos without devpilot
#   bash scripts/update-org.sh <org> --dry-run            # report only, change nothing
#
# Per repo (BASE BRANCH only — feature branches inherit on their next
# rebase/merge): clone → `install.sh --update` (preserves project.config.md
# and .devpilot/config.sh — never delete + re-install) → commit on
# chore/devpilot-update-<ver> → push → PR. Needs: gh (authenticated), git, curl.
# =============================================================================
set -uo pipefail

ORG="${1:-}"; shift || true
[ -z "$ORG" ] && { echo "Usage: update-org.sh <org> [--merge] [--repos a,b] [--install-missing] [--dry-run]"; exit 1; }

MERGE=0; DRY=0; INSTALL_MISSING=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --merge) MERGE=1 ;;
    --dry-run) DRY=1 ;;
    --install-missing) INSTALL_MISSING=1 ;;
    --repos) ONLY="${2:-}"; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
  || { echo "❌ gh CLI must be installed and authenticated (gh auth login)."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "❌ curl is required."; exit 1; }

RAW="https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main"
INSTALLER=$(mktemp "${TMPDIR:-/tmp}/devpilot-install.XXXXXX")
curl -fsSL "$RAW/install.sh" -o "$INSTALLER" || { echo "❌ could not download install.sh"; exit 1; }
VER=$(curl -fsSL "$RAW/VERSION" 2>/dev/null | tr -d '[:space:]'); VER="${VER:-latest}"
BR="chore/devpilot-update-$VER"

echo "── devpilot org update → $ORG (target version: $VER) ─────────────"
[ "$DRY" = 1 ] && echo "   DRY RUN — nothing will be pushed"
echo ""

REPOS=$(gh repo list "$ORG" --limit 300 --no-archived \
  --json name,defaultBranchRef \
  -q '.[] | "\(.name)\t\(.defaultBranchRef.name // "main")"')
[ -z "$REPOS" ] && { echo "No repositories found in $ORG."; exit 1; }

SUMMARY=""
note() { SUMMARY="${SUMMARY}  $1
"; echo "  $1"; }

while IFS=$'\t' read -r NAME DEFBR; do
  [ -z "$NAME" ] && continue
  [ "$NAME" = "devpilot" ] && { note "⏭  $NAME — devpilot source repo, skipped"; continue; }
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",$NAME,"*) : ;; *) continue ;; esac
  fi

  echo ""
  echo "▶ $ORG/$NAME (base: $DEFBR)"
  WORK=$(mktemp -d)
  if ! gh repo clone "$ORG/$NAME" "$WORK/repo" -- --depth 1 --branch "$DEFBR" -q 2>/dev/null; then
    note "❌ $NAME — clone failed"; rm -rf "$WORK"; continue
  fi

  (
    cd "$WORK/repo" || exit 1
    HAS_DP=0
    [ -f project.config.md ] && [ -d .devpilot ] && HAS_DP=1

    if [ "$HAS_DP" = 0 ] && [ "$INSTALL_MISSING" = 0 ]; then
      echo "no-devpilot"; exit 3
    fi
    [ "$DRY" = 1 ] && { echo "would-update"; exit 4; }

    if [ "$HAS_DP" = 1 ]; then
      bash "$INSTALLER" --update >/dev/null 2>&1 || { echo "update-failed"; exit 5; }
    else
      bash "$INSTALLER" --defaults >/dev/null 2>&1 || { echo "install-failed"; exit 5; }
    fi

    git add -A
    git diff --cached --quiet && { echo "up-to-date"; exit 6; }

    git checkout -qb "$BR"
    git commit -qm "chore(devpilot): update to v$VER (managed files only; config preserved)"
    git push -q -u origin "$BR" || { echo "push-failed"; exit 5; }
    gh pr create --base "$DEFBR" --head "$BR" \
      --title "chore(devpilot): update to v$VER" \
      --body "Automated devpilot refresh via \`scripts/update-org.sh\` — \`install.sh --update\` only touches managed files; \`project.config.md\` and \`.devpilot/config.sh\` are untouched. Base branch only; feature branches inherit on rebase/merge." \
      >/dev/null 2>&1 || { echo "pr-failed"; exit 5; }
    if [ "$MERGE" = 1 ]; then
      gh pr merge "$BR" --merge --delete-branch >/dev/null 2>&1 && echo "merged" && exit 0
      gh pr merge "$BR" --merge --auto --delete-branch >/dev/null 2>&1 && echo "auto-merge-armed" && exit 0
      echo "pr-open"; exit 0
    fi
    echo "pr-open"
  ) < /dev/null   # don't let repo-list stdin leak into installer/gh calls
  RC=$?

  case "$RC" in
    0) if [ "$MERGE" = 1 ]; then note "✅ $NAME — updated + PR merged (or auto-merge armed)"; else note "✅ $NAME — PR opened ($BR)"; fi ;;
    3) note "⏭  $NAME — no devpilot install detected (use --install-missing to add it)" ;;
    4) note "🔍 $NAME — would update (dry run)" ;;
    5) note "❌ $NAME — failed (clone OK; update/push/PR step failed — run manually)" ;;
    6) note "✅ $NAME — already up to date" ;;
    *) note "❌ $NAME — unexpected error" ;;
  esac
  rm -rf "$WORK"
done <<EOF
$REPOS
EOF

rm -f "$INSTALLER"
echo ""
echo "── Summary ────────────────────────────────────────────────────────"
printf '%s' "$SUMMARY"
echo "───────────────────────────────────────────────────────────────────"
echo "Note: only base branches were touched. Open feature branches pick the"
echo "update up on their next rebase/merge — do not mass-update branches."
