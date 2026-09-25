#!/usr/bin/env bash
# =============================================================================
# update-org.sh — roll the latest devpilot into EVERY repo of a GitHub org or an
# Azure DevOps organization / project.
#
#   bash scripts/update-org.sh <github-org>                          # a PR per repo
#   bash scripts/update-org.sh https://dev.azure.com/<org>[/<project>]
#                                                                    # Azure Repos (AZDO_PAT)
#   options: --merge            merge each PR when green (GitHub merge / Azure auto-complete)
#            --repos a,b,c      only these repos
#            --install-missing  fresh --defaults install where devpilot isn't present
#            --dry-run          report only, change nothing
#
# Per repo: clone the integration branch (develop when it exists, else the default
# branch) → `install.sh --update` (keeps project.config.md + .devpilot/config.sh —
# never delete + re-install) → commit on chore/devpilot-update-<ver> → push → PR.
# Needs git + curl, and gh (authenticated) for GitHub or AZDO_PAT (Code R/W) for Azure.
# =============================================================================
set -uo pipefail

TARGET="${1:-}"; shift || true
[ -z "$TARGET" ] && { echo "Usage: update-org.sh <github-org | https://dev.azure.com/<org>[/<project>]> [--merge] [--repos a,b] [--install-missing] [--dry-run]"; exit 1; }

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

command -v curl >/dev/null 2>&1 || { echo "❌ curl is required."; exit 1; }
HOST=github
case "$TARGET" in https://dev.azure.com/*|https://*.visualstudio.com*) HOST=azure ;; esac

if [ "$HOST" = github ]; then
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
    || { echo "❌ gh CLI must be installed and authenticated (gh auth login)."; exit 1; }
else
  [ -n "${AZDO_PAT:-}" ] || { echo "❌ export AZDO_PAT=<token> (Code Read & write) to update Azure Repos."; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "❌ jq is required for Azure DevOps."; exit 1; }
fi

RAW="https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main"
INSTALLER=$(mktemp "${TMPDIR:-/tmp}/devpilot-install.XXXXXX")
curl -fsSL "$RAW/install.sh" -o "$INSTALLER" || { echo "❌ could not download install.sh"; exit 1; }
VER=$(curl -fsSL "$RAW/VERSION" 2>/dev/null | tr -d '[:space:]'); VER="${VER:-latest}"
BR="chore/devpilot-update-$VER"
TITLE="chore(devpilot): update to v$VER"
BODY="Automated devpilot refresh via \`scripts/update-org.sh\` — \`install.sh --update\` only touches managed files; \`project.config.md\` and \`.devpilot/config.sh\` are untouched. Integration branch only; feature branches inherit on rebase/merge."

# ── repo inventory: "<display>\t<clone-url>\t<default-branch>" ─────────────────
az_get() { curl -sS --max-time 30 --user ":$AZDO_PAT" -H 'Accept: application/json' "$1"; }
if [ "$HOST" = github ]; then
  REPOS=$(gh repo list "$TARGET" --limit 300 --no-archived --json name,defaultBranchRef \
    -q '.[] | "\(.name)\thttps://github.com/'"$TARGET"'/\(.name).git\t\(.defaultBranchRef.name // "main")"')
else
  ORG_URL=$(printf '%s' "$TARGET" | sed -E 's#^(https://dev\.azure\.com/[^/]+).*#\1#; s#^(https://[^/.]+\.visualstudio\.com).*#\1#')
  PROJECT=$(printf '%s' "${TARGET#"$ORG_URL"}" | sed 's#^/##; s#/.*##')
  if [ -n "$PROJECT" ]; then PROJECTS="$PROJECT"
  else PROJECTS=$(az_get "$ORG_URL/_apis/projects?\$top=500&api-version=7.1" | jq -r '.value[].name'); fi
  REPOS=$(printf '%s\n' "$PROJECTS" | while IFS= read -r P; do
    [ -z "$P" ] && continue
    az_get "$ORG_URL/$(jq -rn --arg s "$P" '$s|@uri')/_apis/git/repositories?api-version=7.1" \
      | jq -r --arg p "$P" '.value[] | select(.isDisabled != true and .defaultBranch != null)
          | "\($p)/\(.name)\t\(.remoteUrl)\t\(.defaultBranch | sub("refs/heads/"; ""))"'
  done)
fi
[ -z "$REPOS" ] && { echo "No repositories found in $TARGET."; exit 1; }

echo "── devpilot org update → $TARGET ($HOST · target version: $VER) ─────────────"
[ "$DRY" = 1 ] && echo "   DRY RUN — nothing will be pushed"

SUMMARY=""
note() { SUMMARY="${SUMMARY}  $1
"; echo "  $1"; }

while IFS=$'\t' read -r NAME URL DEFBR; do
  [ -z "$NAME" ] && continue
  case "${NAME##*/}" in devpilot) note "⏭  $NAME — devpilot source repo, skipped"; continue ;; esac
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",$NAME,"*|*",${NAME##*/},"*) : ;; *) continue ;; esac
  fi

  echo ""
  WORK=$(mktemp -d)
  GITAUTH=()
  [ "$HOST" = azure ] && GITAUTH=(-c "http.extraHeader=Authorization: Basic $(printf ':%s' "$AZDO_PAT" | base64 | tr -d '\n')")
  # Integration branch: develop when it exists (DevPilot's base), else the default branch.
  BASE="$DEFBR"
  git "${GITAUTH[@]+"${GITAUTH[@]}"}" ls-remote --exit-code --heads "$URL" develop >/dev/null 2>&1 && BASE="develop"
  echo "▶ $NAME (base: $BASE)"
  if ! git "${GITAUTH[@]+"${GITAUTH[@]}"}" clone -q --depth 1 --branch "$BASE" "$URL" "$WORK/repo" 2>/dev/null; then
    note "❌ $NAME — clone failed"; rm -rf "$WORK"; continue
  fi

  (
    cd "$WORK/repo" || exit 1
    [ "$HOST" = azure ] && git config http.extraHeader "${GITAUTH[1]#http.extraHeader=}"
    HAS_DP=0
    [ -f project.config.md ] && [ -d .devpilot ] && HAS_DP=1
    if [ "$HAS_DP" = 0 ] && [ "$INSTALL_MISSING" = 0 ]; then echo "no-devpilot"; exit 3; fi
    [ "$DRY" = 1 ] && exit 4

    if [ "$HAS_DP" = 1 ]; then bash "$INSTALLER" --update >/dev/null 2>&1 || exit 5
    else bash "$INSTALLER" --defaults >/dev/null 2>&1 || exit 5; fi

    git add -A
    git diff --cached --quiet && exit 6
    git checkout -qb "$BR"
    git commit -qm "$TITLE (managed files only; config preserved)" --no-verify
    git push -q -u origin "$BR" || exit 5

    if [ "$HOST" = github ]; then
      gh pr create --base "$BASE" --head "$BR" --title "$TITLE" --body "$BODY" >/dev/null 2>&1 || exit 5
      if [ "$MERGE" = 1 ]; then
        gh pr merge "$BR" --squash --delete-branch >/dev/null 2>&1 && exit 0
        gh pr merge "$BR" --squash --auto --delete-branch >/dev/null 2>&1 && exit 0
      fi
    else
      PR=$(bash scripts/azdo.sh pr-create "$BASE" "$TITLE" "$BODY" 2>/dev/null) || exit 5
      echo "  $PR"
      [ "$MERGE" = 1 ] && { bash scripts/azdo.sh pr-complete "${PR##*/}" >/dev/null 2>&1; RC=$?; [ "$RC" = 0 ] || [ "$RC" = 3 ] && exit 0; }
    fi
    exit 0
  ) < /dev/null   # don't let the repo list leak into installer/gh calls
  RC=$?

  case "$RC" in
    0) if [ "$MERGE" = 1 ]; then note "✅ $NAME — updated; PR merged or set to merge when green"; else note "✅ $NAME — PR opened ($BR → $BASE)"; fi ;;
    3) note "⏭  $NAME — no devpilot install detected (use --install-missing to add it)" ;;
    4) note "🔍 $NAME — would update (dry run)" ;;
    5) note "❌ $NAME — update/push/PR step failed — run manually" ;;
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
echo "Note: only integration branches were touched. Open feature branches pick the"
echo "update up on their next rebase/merge — do not mass-update branches."
