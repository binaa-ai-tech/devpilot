#!/usr/bin/env bash
# =============================================================================
# azdo.sh — Azure DevOps backend: Boards (work items, iterations as sprints),
# Repos (pull requests) and Pipelines (PR build status). REST API 7.1, PAT auth.
#
# Boards (called through scripts/tracker.sh — same interface as jira.sh):
#   ping · new <Epic|Story|Bug|Task> <summary> <body> [parent] [tags,csv] → ADO-<id>
#   show · search · list · status · comment · describe · link · url · ref
#   sprint-create · sprint-assign · sprint-start · sprint-active · sprint-close · sprint-list
#
# Repos + Pipelines (called by open-pr.sh and /dp-pr when the git host is Azure):
#   pr-create <base> <title> <body-file|text> [--items "ADO-1 ADO-2"]   → PR URL
#   pr-show <id>        STATUS= MERGE_STATUS= POLICIES_* URL= (key=value lines)
#   pr-complete <id> [--merge-commit] [--keep-branch]
#                       auto-complete (squash + delete branch by default); exit 0 merged, 3 waiting
#   pr-threads <id>     active review threads (TSV: thread-id  file:line  author  text)
#   pr-reply <id> <thread-id> <text> [--resolve]
#   ci <pr-id|branch> [--log]   latest pipeline run (+ failed-step log tails)
#
# Config (.devpilot/config.sh or environment): AZDO_ORG_URL (https://dev.azure.com/<org>),
# AZDO_PROJECT, AZDO_PAT (scopes: Work Items R/W, Code R/W, Build R), optional AZDO_TEAM,
# AZDO_STORY_TYPE. Repos org/project/repo come from the origin remote when not set.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
dp_load_secrets

V="api-version=7.1"
die() { echo "❌ azdo: $*" >&2; exit 1; }

# ── Repo coordinates from the origin remote ──────────────────────────────────
R_ORG=""; R_PROJ=""; R_REPO=""
_parse_remote() {
  local u p rest org h
  u=$(dp_remote_url)
  case "$u" in
    *ssh.dev.azure.com:v3/*)
      p="${u#*:v3/}"; org="${p%%/*}"; rest="${p#*/}"
      R_PROJ="${rest%%/*}"; R_REPO="${rest#*/}"; R_ORG="https://dev.azure.com/$org" ;;
    *dev.azure.com/*)
      p="${u#*dev.azure.com/}"; org="${p%%/*}"; rest="${p#*/}"
      R_PROJ="${rest%%/_git/*}"; R_REPO="${rest#*/_git/}"; R_ORG="https://dev.azure.com/$org" ;;
    *.visualstudio.com/*)
      h="${u#*://}"; h="${h#*@}"; org="${h%%.visualstudio.com*}"
      p="${h#*.visualstudio.com/}"; p="${p#DefaultCollection/}"
      R_PROJ="${p%%/_git/*}"; R_REPO="${p#*/_git/}"; R_ORG="https://dev.azure.com/$org" ;;
  esac
  R_REPO="${R_REPO%.git}"; R_REPO="${R_REPO%/}"
  # Remotes carry %20 for spaces — decode to real names; we re-encode per request.
  R_PROJ=$(printf '%b' "${R_PROJ//%/\\x}"); R_REPO=$(printf '%b' "${R_REPO//%/\\x}")
  [ -n "${AZDO_REPO:-}" ] && R_REPO="$AZDO_REPO"
  [ -z "$R_ORG" ] && R_ORG="$AZDO_ORG_URL"
  [ -z "$R_PROJ" ] && R_PROJ="$AZDO_PROJECT"
  return 0
}
_parse_remote
ORG="${AZDO_ORG_URL:-$R_ORG}"
PROJ="${AZDO_PROJECT:-$R_PROJ}"
TEAM="${AZDO_TEAM:-$PROJ Team}"
P="$ORG/$(dp_urlenc "$PROJ")"
RP="$R_ORG/$(dp_urlenc "$R_PROJ")"
REPO_API="$RP/_apis/git/repositories/$(dp_urlenc "$R_REPO")"

# _az <METHOD> <url> [json] [content-type] → body; non-2xx → stderr + rc 1
_az() {
  local method="$1" url="$2" data="${3:-}" ctype="${4:-application/json}" tmp code
  [ -n "${AZDO_PAT:-}" ] || die "AZDO_PAT is not set (bash scripts/tracker.sh setup azure …)"
  tmp=$(mktemp)
  if [ -n "$data" ]; then
    code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 -X "$method" --user ":$AZDO_PAT" \
      -H "Content-Type: $ctype" -H 'Accept: application/json' --data "$data" "$url" 2>/dev/null)
  else
    code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 -X "$method" --user ":$AZDO_PAT" \
      -H 'Accept: application/json' "$url" 2>/dev/null)
  fi
  if [ "${code:-000}" -ge 200 ] 2>/dev/null && [ "$code" -lt 300 ]; then
    cat "$tmp"; rm -f "$tmp"; return 0
  fi
  echo "azdo HTTP ${code:-000} $method ${url#"$ORG"}: $(head -c 400 "$tmp")" >&2
  rm -f "$tmp"; return 1
}
_patch() { _az PATCH "$1" "$2" "application/json-patch+json"; }

_id() { printf '%s' "$1" | grep -oE '[0-9]+' | tail -1; }
_text_or_file() { if [ -f "$1" ]; then cat "$1"; else printf '%s' "$1"; fi; }

# Markdown subset → HTML (Boards descriptions and comments render HTML).
_md_html() {
  _text_or_file "$1" | awk '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
    function close_list() { if (lst != "") { printf "</%s>", lst; lst = "" } }
    /^```/ { if (code) { printf "</pre>"; code = 0 } else { close_list(); printf "<pre>"; code = 1 } next }
    code   { printf "%s\n", esc($0); next }
    /^[[:space:]]*$/ { close_list(); next }
    /^#+ / { close_list(); n = index($0, " "); l = n - 1; if (l < 2) l = 2; if (l > 4) l = 4
                 printf "<h%d>%s</h%d>", l, esc(substr($0, n + 1)), l; next }
    /^[[:space:]]*[-*] / { s = $0; sub(/^[[:space:]]*[-*] +/, "", s)
                 if (lst != "ul") { close_list(); printf "<ul>"; lst = "ul" } printf "<li>%s</li>", esc(s); next }
    /^[[:space:]]*[0-9]+\. / { s = $0; sub(/^[[:space:]]*[0-9]+\. +/, "", s)
                 if (lst != "ol") { close_list(); printf "<ol>"; lst = "ol" } printf "<li>%s</li>", esc(s); next }
    { close_list(); printf "<div>%s</div>", esc($0) }
    END { close_list(); if (code) printf "</pre>" }'
}

_types() { _az GET "$P/_apis/wit/workitemtypes?$V" | jq -r '.value[].name'; }
_story_type() {
  [ -n "${AZDO_STORY_TYPE:-}" ] && { echo "$AZDO_STORY_TYPE"; return; }
  local all t; all=$(_types)
  for t in "User Story" "Product Backlog Item" "Requirement" "Issue"; do
    printf '%s\n' "$all" | grep -qx "$t" && { echo "$t"; return; }
  done
  echo "Task"
}

FIELDS='["System.Id","System.WorkItemType","System.State","System.Title","System.Parent"]'
# Batch-fetch ids (≤200 per call) → TSV rows.
_rows() {
  local ids="$1" chunk
  [ -z "$ids" ] && return 0
  printf '%s\n' $ids | while read -r first; do
    chunk="$first"
    for _ in $(seq 1 199); do read -r n || break; chunk="$chunk $n"; done
    _az POST "$ORG/_apis/wit/workitemsbatch?$V" \
      "$(jq -n --argjson f "$FIELDS" --arg ids "$chunk" '{ids:($ids|split(" ")|map(tonumber)), fields:$f}')" \
    | jq -r '.value[] | .fields as $f | [ "ADO-\(.id)", ($f["System.WorkItemType"] // "-"), ($f["System.State"] // "-"),
        (($f["System.State"] // "") as $s
          | if (["Done","Closed","Removed","Resolved","Completed"] | index($s)) then "done"
            elif (["New","To Do","Proposed","Approved"] | index($s)) then "todo" else "doing" end),
        (if $f["System.Parent"] then "ADO-\($f["System.Parent"])" else "-" end),
        (($f["System.Title"] // "-") | gsub("[\t\n]"; " ")) ] | @tsv'
  done
}
_wiql_ids() {  # _wiql_ids <query> [top]
  _az POST "$P/_apis/wit/wiql?$V&\$top=${2:-200}" "$(jq -n --arg q "$1" '{query:$q}')" \
    | jq -r '[.workItems[].id] | map(tostring) | join(" ")'
}
_iteration_path() { printf '%s\\%s' "$PROJ" "$1"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  ping)
    _az GET "$ORG/_apis/projects/$(dp_urlenc "$PROJ")?$V" >/dev/null \
      || die "cannot reach project '$PROJ' at $ORG (check AZDO_ORG_URL / AZDO_PROJECT / AZDO_PAT scopes)"
    echo "✅ Azure DevOps reachable — $ORG / $PROJ"
    ;;

  new)
    TYPE="${1:?type}"; SUMMARY="${2:?summary}"; BODY="${3:-}"; PARENT="${4:-}"; TAGS="${5:-}"
    case "$TYPE" in
      Epic) WIT="Epic" ;;
      Bug)  ALL=$(_types); if printf '%s\n' "$ALL" | grep -qx "Bug"; then WIT="Bug"; else WIT=$(_story_type); TAGS="bug${TAGS:+,$TAGS}"; fi ;;
      Task|Subtask) WIT="Task" ;;
      *)    WIT=$(_story_type) ;;
    esac
    HTML=$(_md_html "${BODY:- }")
    DOC=$(jq -n --arg t "$SUMMARY" --arg d "$HTML" --arg tags "$TAGS" --arg wit "$WIT" \
               --arg parent "$(_id "$PARENT")" --arg org "$ORG" '
      [ {op:"add", path:"/fields/System.Title", value:$t},
        {op:"add", path:"/fields/System.Description", value:$d} ]
      + (if $wit == "Bug" then [{op:"add", path:"/fields/Microsoft.VSTS.TCM.ReproSteps", value:$d}] else [] end)
      + (if $tags != "" then [{op:"add", path:"/fields/System.Tags", value:($tags|split(",")|join("; "))}] else [] end)
      + (if $parent != "" then [{op:"add", path:"/relations/-", value:{rel:"System.LinkTypes.Hierarchy-Reverse",
            url:"\($org)/_apis/wit/workItems/\($parent)"}}] else [] end)')
    ID=$(_patch "$P/_apis/wit/workitems/\$$(dp_urlenc "$WIT")?$V" "$DOC" | jq -r '.id // empty')
    [ -n "$ID" ] || die "could not create $WIT '$SUMMARY'"
    echo "ADO-$ID"
    ;;

  show)
    ID=$(_id "${1:?KEY}")
    R=$(_az GET "$ORG/_apis/wit/workitems/$ID?\$expand=relations&$V") || exit 1
    echo "$R" | jq -r '.fields as $f | "Key:    ADO-\(.id)", "Type:   \($f["System.WorkItemType"])",
      "State:  \($f["System.State"])", "Parent: \(if $f["System.Parent"] then "ADO-\($f["System.Parent"])" else "-" end)",
      "Title:  \($f["System.Title"])", "Description:",
      (($f["System.Description"] // "") | gsub("<[^>]*>"; " ") | gsub("\\s+"; " ") | .[0:1500])'
    echo "Children:"
    KIDS=$(echo "$R" | jq -r '[.relations[]? | select(.rel == "System.LinkTypes.Hierarchy-Forward") | .url | split("/") | last] | join(" ")')
    _rows "$KIDS" | sed 's/^/  /'
    ;;

  search)
    WORDS=$(printf '%s' "${1:?text}" | tr -c '[:alnum:]' ' ' | tr -s ' ' '\n' | awk 'length >= 3' | head -6)
    [ -z "$WORDS" ] && exit 0
    COND=$(printf '%s\n' "$WORDS" | awk '{ printf "%s[System.Title] CONTAINS '\''%s'\''", (NR > 1 ? " OR " : ""), $0 }')
    IDS=$(_wiql_ids "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND ($COND) ORDER BY [System.ChangedDate] DESC" 25)
    _rows "$IDS"
    ;;

  list)
    IDS=$(_wiql_ids "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND ([System.WorkItemType] IN GROUP 'Microsoft.RequirementCategory' OR [System.WorkItemType] IN ('Epic','Feature','Bug','Task')) ORDER BY [System.Id]" 500)
    _rows "$IDS"
    ;;

  status)
    ID=$(_id "${1:?KEY}"); WANT="${2:?status}"
    case "$(echo "$WANT" | tr '[:upper:]' '[:lower:]')" in
      done|closed|resolved) CAT="Completed" ;;
      "in progress"|doing|active) CAT="InProgress" ;;
      *) CAT="Proposed" ;;
    esac
    WIT=$(_az GET "$ORG/_apis/wit/workitems/$ID?fields=System.WorkItemType&$V" | jq -r '.fields["System.WorkItemType"]') || exit 1
    STATE=$(_az GET "$P/_apis/wit/workitemtypes/$(dp_urlenc "$WIT")/states?$V" | jq -r --arg w "$WANT" --arg c "$CAT" '
      ([.value[] | select((.name|ascii_downcase) == ($w|ascii_downcase))] + [.value[] | select(.category == $c)]) | first | .name // empty')
    [ -n "$STATE" ] || die "no '$WANT' state for $WIT"
    _patch "$ORG/_apis/wit/workitems/$ID?$V" "$(jq -n --arg s "$STATE" '[{op:"add", path:"/fields/System.State", value:$s}]')" >/dev/null || exit 1
    echo "ADO-$ID → $STATE" >&2
    ;;

  comment)
    ID=$(_id "${1:?KEY}")
    _az POST "$P/_apis/wit/workItems/$ID/comments?api-version=7.1-preview.4" \
      "$(jq -n --arg t "$(_md_html "${2:?text}")" '{text:$t}')" >/dev/null || exit 1
    echo "💬 comment → ADO-$ID" >&2
    ;;

  describe)
    ID=$(_id "${1:?KEY}")
    _patch "$ORG/_apis/wit/workitems/$ID?$V" \
      "$(jq -n --arg d "$(_md_html "${2:?file or text}")" '[{op:"add", path:"/fields/System.Description", value:$d}]')" >/dev/null || exit 1
    echo "📝 description → ADO-$ID" >&2
    ;;

  link)
    FROM=$(_id "${1:?KEY}"); KIND="${2:?duplicate|relates}"; TO=$(_id "${3:?KEY2}")
    case "$KIND" in duplicate|Duplicate) REL="System.LinkTypes.Duplicate-Reverse" ;; *) REL="System.LinkTypes.Related" ;; esac
    _patch "$ORG/_apis/wit/workitems/$FROM?$V" "$(jq -n --arg r "$REL" --arg u "$ORG/_apis/wit/workItems/$TO" \
      '[{op:"add", path:"/relations/-", value:{rel:$r, url:$u}}]')" >/dev/null || exit 1
    echo "🔗 ADO-$FROM $KIND → ADO-$TO" >&2
    ;;

  url) echo "$P/_workitems/edit/$(_id "${1:?KEY}")" ;;
  ref) echo "AB#$(_id "${1:?KEY}")" ;;

  sprint-create)
    NAME="${1:?name}"
    NODE=$(_az POST "$P/_apis/wit/classificationnodes/Iterations?$V" "$(jq -n --arg n "$NAME" \
      --arg s "$(dp_today)T00:00:00Z" --arg e "$(dp_date_plus 14)T00:00:00Z" \
      '{name:$n, attributes:{startDate:$s, finishDate:$e}}')") || exit 1
    GUID=$(echo "$NODE" | jq -r '.identifier')
    _az POST "$P/$(dp_urlenc "$TEAM")/_apis/work/teamsettings/iterations?$V" "{\"id\":\"$GUID\"}" >/dev/null \
      || echo "⚠️  iteration created but not added to team '$TEAM' (set AZDO_TEAM)" >&2
    echo "$NAME"
    ;;

  sprint-assign)
    NAME="${1:?sprint}"; shift; [ "$#" -gt 0 ] || die "no work item keys"
    for K in "$@"; do
      _patch "$ORG/_apis/wit/workitems/$(_id "$K")?$V" "$(jq -n --arg p "$(_iteration_path "$NAME")" \
        '[{op:"add", path:"/fields/System.IterationPath", value:$p}]')" >/dev/null || exit 1
    done
    echo "🗂 $* → iteration $NAME" >&2
    ;;

  sprint-start) exit 0 ;;   # iterations are dated at creation

  sprint-active)
    _az GET "$P/$(dp_urlenc "$TEAM")/_apis/work/teamsettings/iterations?\$timeframe=current&$V" \
      | jq -r '.value[0].name // empty'
    ;;

  sprint-close)
    NAME="${1:?sprint}"
    OPEN=$(_wiql_ids "SELECT [System.Id] FROM WorkItems WHERE [System.IterationPath] = '$(_iteration_path "$NAME")' AND [System.State] NOT IN ('Done','Closed','Removed','Resolved','Completed')" 200 | wc -w | tr -d ' ')
    [ "${OPEN:-0}" -gt 0 ] && { echo "open:$OPEN"; exit 4; }
    NODE_URL="$P/_apis/wit/classificationnodes/Iterations/$(dp_urlenc "$NAME")?$V"
    START=$(_az GET "$NODE_URL" | jq -r '.attributes.startDate // empty')
    [ -z "$START" ] && START="$(dp_today)T00:00:00Z"
    _az PATCH "$NODE_URL" "$(jq -n --arg s "$START" --arg e "$(dp_today)T00:00:00Z" \
      '{attributes:{startDate:$s, finishDate:$e}}')" >/dev/null || exit 1
    echo "closed"
    ;;

  sprint-list)
    _az GET "$P/$(dp_urlenc "$TEAM")/_apis/work/teamsettings/iterations?$V" \
      | jq -r '.value[] | [.name, (.attributes.timeFrame // "-"), .path] | @tsv'
    ;;

  delete)   # to the Boards recycle bin (restorable)
    _az DELETE "$P/_apis/wit/workitems/$(_id "${1:?KEY}")?$V" >/dev/null || exit 1
    echo "🗑 ${1} deleted (recycle bin)" >&2
    ;;
  sprint-delete)
    _az DELETE "$P/_apis/wit/classificationnodes/Iterations/$(dp_urlenc "${1:?sprint}")?$V" >/dev/null || exit 1
    echo "🗑 iteration ${1} deleted" >&2
    ;;

  # ── Repos ──────────────────────────────────────────────────────────────────
  pr-create)
    BASE="${1:?base}"; TITLE="${2:?title}"; BODY="${3:-}"; shift 3 || true; ITEMS=""
    while [ $# -gt 0 ]; do case "$1" in --items) ITEMS="${2:-}"; shift 2 ;; *) shift ;; esac; done
    SRC=$(git branch --show-current)
    DESC=$(_text_or_file "${BODY:-Opened by DevPilot}" | head -c 3900)
    REFS=$(for k in $ITEMS; do case "$k" in ADO-*|AB#*) echo "$(_id "$k")";; esac; done | jq -R . | jq -s 'map({id:.})')
    R=$(_az POST "$REPO_API/pullrequests?$V" "$(jq -n --arg s "refs/heads/$SRC" --arg t "refs/heads/$BASE" \
         --arg ti "$TITLE" --arg d "$DESC" --argjson w "$REFS" \
         '{sourceRefName:$s, targetRefName:$t, title:$ti, description:$d, workItemRefs:$w}')" 2>/dev/null) \
      || R=$(_az GET "$REPO_API/pullrequests?searchCriteria.sourceRefName=refs/heads/$SRC&searchCriteria.targetRefName=refs/heads/$BASE&searchCriteria.status=active&$V" \
             | jq '.value[0] // empty')
    ID=$(echo "$R" | jq -r '.pullRequestId // empty')
    [ -n "$ID" ] || die "could not create a PR $SRC → $BASE"
    echo "$R_ORG/$(dp_urlenc "$R_PROJ")/_git/$(dp_urlenc "$R_REPO")/pullrequest/$ID"
    ;;

  pr-show)
    ID=$(_id "${1:?pr-id}")
    R=$(_az GET "$REPO_API/pullrequests/$ID?$V") || exit 1
    PID=$(echo "$R" | jq -r '.repository.project.id')
    EV=$(_az GET "$RP/_apis/policy/evaluations?artifactId=$(dp_urlenc "vstfs:///CodeReview/CodeReviewId/$PID/$ID")&api-version=7.1-preview.1" 2>/dev/null || echo '{"value":[]}')
    echo "$R" | jq -r '"STATUS=\(.status)", "MERGE_STATUS=\(.mergeStatus // "unknown")", "DRAFT=\(.isDraft)",
      "SOURCE=\(.sourceRefName | sub("refs/heads/"; ""))", "TARGET=\(.targetRefName | sub("refs/heads/"; ""))",
      "AUTO_COMPLETE=\(if .autoCompleteSetBy then "armed" else "off" end)"'
    echo "$EV" | jq -r '"POLICIES_APPROVED=\([.value[] | select(.status == "approved")] | length)",
      "POLICIES_RUNNING=\([.value[] | select(.status == "running" or .status == "queued")] | length)",
      "POLICIES_REJECTED=\([.value[] | select(.status == "rejected" or .status == "broken")] | map(.configuration.type.displayName) | join(",") | if . == "" then "0" else . end)"'
    echo "URL=$R_ORG/$(dp_urlenc "$R_PROJ")/_git/$(dp_urlenc "$R_REPO")/pullrequest/$ID"
    ;;

  pr-complete)
    ID=$(_id "${1:?pr-id}"); STRATEGY="squash"; DELETE=true
    for O in "${@:2}"; do case "$O" in --merge-commit) STRATEGY="noFastForward" ;; --keep-branch) DELETE=false ;; esac; done
    R=$(_az GET "$REPO_API/pullrequests/$ID?$V") || exit 1
    [ "$(echo "$R" | jq -r '.status')" = "completed" ] && { echo "merged"; exit 0; }
    # Without a build-validation policy, auto-complete would merge instantly with no
    # server-side CI. Refuse unless explicitly allowed.
    PID=$(echo "$R" | jq -r '.repository.project.id')
    BUILDS=$(_az GET "$RP/_apis/policy/evaluations?artifactId=$(dp_urlenc "vstfs:///CodeReview/CodeReviewId/$PID/$ID")&api-version=7.1-preview.1" 2>/dev/null \
      | jq '[.value[]? | select(.configuration.type.id == "0609b952-1397-4640-95ec-e00a01b2c241" and .configuration.isBlocking)] | length' 2>/dev/null)
    if [ "${BUILDS:-0}" -eq 0 ] && [ "${AZDO_ALLOW_UNPROTECTED:-0}" != "1" ]; then
      echo "not merged: '$(echo "$R" | jq -r '.targetRefName | sub("refs/heads/"; "")')' has no required build validation, so CI would be skipped." >&2
      echo "  Fix once: bash scripts/protect-branches.sh   (or AZDO_ALLOW_UNPROTECTED=1 to merge on local gates only)" >&2
      echo "unprotected"
      exit 3
    fi
    _az PATCH "$REPO_API/pullrequests/$ID?$V" "$(echo "$R" | jq --arg s "$STRATEGY" --argjson d "$DELETE" '{autoCompleteSetBy:{id:.createdBy.id},
      completionOptions:{mergeStrategy:$s, deleteSourceBranch:$d, transitionWorkItems:false,
      mergeCommitMessage:"\(.title) (PR \(.pullRequestId))"}}')" >/dev/null || exit 1
    WAIT="${AZDO_MERGE_WAIT:-120}"; T=0
    while [ "$T" -lt "$WAIT" ]; do
      S=$(_az GET "$REPO_API/pullrequests/$ID?$V" | jq -r '"\(.status) \(.mergeStatus // "")"')
      case "$S" in
        completed*) echo "merged"; exit 0 ;;
        *conflicts*) echo "conflicts"; exit 1 ;;
      esac
      sleep 10; T=$((T + 10))
    done
    echo "auto-complete armed — completes when branch policies pass"
    exit 3
    ;;

  pr-threads)
    ID=$(_id "${1:?pr-id}")
    _az GET "$REPO_API/pullrequests/$ID/threads?$V" | jq -r '.value[]
      | select((.status == "active" or .status == "pending") and (.isDeleted | not) and (.comments[0].commentType == "text"))
      | [ .id, "\(.threadContext.filePath // "-"):\(.threadContext.rightFileStart.line // "")",
          .comments[0].author.displayName, (.comments[0].content | gsub("[\t\n]"; " ") | .[0:300]) ] | @tsv'
    ;;

  pr-reply)
    ID=$(_id "${1:?pr-id}"); TID="${2:?thread-id}"; TEXT="${3:?text}"
    _az POST "$REPO_API/pullrequests/$ID/threads/$TID/comments?$V" \
      "$(jq -n --arg c "$TEXT" '{content:$c, parentCommentId:1, commentType:1}')" >/dev/null || exit 1
    [ "${4:-}" = "--resolve" ] && _az PATCH "$REPO_API/pullrequests/$ID/threads/$TID?$V" '{"status":"fixed"}' >/dev/null
    echo "💬 replied on thread $TID" >&2
    ;;

  ci)
    TARGET="${1:?pr-id or branch}"
    if printf '%s' "$TARGET" | grep -qE '^[0-9]+$'; then REF="refs/pull/$TARGET/merge"; else REF="refs/heads/$TARGET"; fi
    B=$(_az GET "$RP/_apis/build/builds?branchName=$(dp_urlenc "$REF")&\$top=1&queryOrder=queueTimeDescending&$V" | jq '.value[0] // empty')
    [ -n "$B" ] || { echo "CI=none"; exit 0; }
    echo "$B" | jq -r '"CI=\(.status)", "RESULT=\(.result // "pending")", "BUILD_ID=\(.id)", "URL=\(._links.web.href)"'
    if [ "${2:-}" = "--log" ]; then
      BID=$(echo "$B" | jq -r '.id')
      _az GET "$RP/_apis/build/builds/$BID/timeline?$V" \
        | jq -r '.records[] | select(.result == "failed" and .log != null) | "\(.name)\t\(.log.url)"' \
        | while IFS="$(printf '\t')" read -r NAME LOG; do
            echo "── failed: $NAME"
            curl -sS --max-time 30 --user ":$AZDO_PAT" "$LOG" | tail -n "${TEST_MAX_LINES:-40}"
          done
    fi
    ;;

  # ── Governance: pipelines, branch policies, environments ───────────────────
  repo-id)
    _az GET "$REPO_API?$V" | jq -r '.id'
    ;;

  pipeline-ensure)   # pipeline-ensure <name> <yaml-path> → definition id (creates it once)
    NAME="${1:?name}"; YML="${2:?yaml path}"
    RID=$(bash "$0" repo-id) || exit 1
    ID=$(_az GET "$RP/_apis/pipelines?$V" | jq -r --arg n "$NAME" '.value[] | select(.name == $n) | .id' | head -1)
    if [ -z "$ID" ]; then
      ID=$(_az POST "$RP/_apis/pipelines?$V" "$(jq -n --arg n "$NAME" --arg p "/${YML#/}" --arg r "$RID" \
        '{name:$n, configuration:{type:"yaml", path:$p, repository:{id:$r, type:"azureReposGit"}}}')" | jq -r '.id // empty')
      [ -n "$ID" ] || die "could not create pipeline '$NAME' — is $YML committed on the default branch?"
      echo "  ✚ pipeline $NAME ($YML)" >&2
    fi
    echo "$ID"
    ;;

  protect)   # protect <branch> [--reviewers N] [--build <definition-id>]
             # merge types: main → merge commit only (release/hotfix PRs); others → squash
             # (features) + merge commit (release/hotfix back-merges)
    BR="${1:?branch}"; shift; REVIEWERS=0; BUILD=""
    while [ $# -gt 0 ]; do case "$1" in --reviewers) REVIEWERS="${2:-0}"; shift 2 ;; --build) BUILD="${2:-}"; shift 2 ;; *) shift ;; esac; done
    RID=$(bash "$0" repo-id) || exit 1
    SCOPE=$(jq -n --arg r "$RID" --arg b "refs/heads/$BR" '[{repositoryId:$r, refName:$b, matchKind:"exact"}]')
    EXISTING=$(_az GET "$RP/_apis/git/policy/configurations?repositoryId=$RID&refName=$(dp_urlenc "refs/heads/$BR")&$V" 2>/dev/null || echo '{"value":[]}')
    upsert() {  # upsert <type-guid> <label> <blocking> <settings-json>
      local body id
      body=$(jq -n --arg t "$1" --argjson b "$3" --argjson s "$4" --argjson scope "$SCOPE" \
        '{isEnabled:true, isBlocking:$b, type:{id:$t}, settings:($s + {scope:$scope})}') \
        && [ -n "$body" ] || { echo "  ❌ $BR — $2 (bad policy body)" >&2; return 1; }
      id=$(echo "$EXISTING" | jq -r --arg t "$1" '[.value[] | select(.type.id == $t)] | first | .id // empty')
      if [ -n "$id" ]; then _az PUT "$RP/_apis/policy/configurations/$id?$V" "$body" >/dev/null && echo "  ✅ $BR — $2 (updated)"
      else _az POST "$RP/_apis/policy/configurations?$V" "$body" >/dev/null && echo "  ✅ $BR — $2"; fi
    }
    RC=0
    [ -n "$BUILD" ] && { upsert 0609b952-1397-4640-95ec-e00a01b2c241 "build validation: devpilot-ci required" true \
      "$(jq -n --argjson d "$BUILD" '{buildDefinitionId:$d, displayName:"devpilot-ci", queueOnSourceUpdateOnly:false, manualQueueOnly:false, validDuration:0}')" || RC=1; }
    if [ "$BR" = "main" ]; then
      upsert fa4e907d-c16b-4a4c-9dfa-4916e5d171ab "merge commits only (release/hotfix PRs)" true \
        '{"allowSquash":false,"allowNoFastForward":true,"allowRebase":false,"allowRebaseMerge":false}' || RC=1
    else
      upsert fa4e907d-c16b-4a4c-9dfa-4916e5d171ab "squash (features) + merge commit (back-merges)" true \
        '{"allowSquash":true,"allowNoFastForward":true,"allowRebase":false,"allowRebaseMerge":false}' || RC=1
    fi
    upsert c6a1889d-b943-4856-b76f-9e46bb6b0df2 "review comments must be resolved" true '{}' || RC=1
    upsert 40e92b44-2fe1-4dd6-b3d8-74a9c21d0c6e "linked work items (advisory)" false '{}' || RC=1
    if [ "$REVIEWERS" -gt 0 ]; then
      upsert fa6ba251-8c60-4a0b-bf2e-3ea6e0b34e98 "$REVIEWERS approving reviewer(s)" true \
        "$(jq -n --argjson n "$REVIEWERS" '{minimumApproverCount:$n, creatorVoteCounts:false, allowDownvotes:false, resetOnSourcePush:true}')" || RC=1
    fi
    exit $RC
    ;;

  identity)   # identity <email | "[Project]\\Group"> → identity id (for approvers)
    Q="${1:?email or group}"
    VSSPS=$(printf '%s' "$R_ORG" | sed -E 's#^https://dev\.azure\.com/#https://vssps.dev.azure.com/#')
    _az GET "$VSSPS/_apis/identities?searchFilter=General&filterValue=$(dp_urlenc "$Q")&queryMembership=None&api-version=7.1" \
      | jq -r '.value[0].id // empty'
    ;;

  env-setup)   # env-setup <name> [--approval] → create the Pipelines environment (+ approval check)
               # approvers: DEVPILOT_APPROVERS="a@corp.com,[Shop]\Release Managers" (default: the PAT owner)
    NAME="${1:?environment}"; APPROVAL="${2:-}"
    ENV=$(_az GET "$RP/_apis/distributedtask/environments?name=$(dp_urlenc "$NAME")&api-version=7.1-preview.1" | jq '.value[0] // empty')
    [ -z "$ENV" ] && ENV=$(_az POST "$RP/_apis/distributedtask/environments?api-version=7.1-preview.1" \
      "$(jq -n --arg n "$NAME" '{name:$n, description:"DevPilot delivery stage"}')")
    EID=$(echo "$ENV" | jq -r '.id // empty'); [ -n "$EID" ] || die "could not create environment $NAME"
    if [ "$APPROVAL" = "--approval" ]; then
      IDS=""; WHO=""
      if [ -n "${DEVPILOT_APPROVERS:-}" ]; then
        OLDIFS="$IFS"; IFS=','
        for A in $DEVPILOT_APPROVERS; do
          A=$(printf '%s' "$A" | sed 's/^ *//; s/ *$//'); [ -z "$A" ] && continue
          AID=$(bash "$0" identity "$A" 2>/dev/null)
          if [ -n "$AID" ]; then IDS="$IDS $AID"; WHO="$WHO, $A"; else echo "  ⚠️  approver '$A' not found in Azure DevOps — skipped" >&2; fi
        done
        IFS="$OLDIFS"
      fi
      if [ -z "$IDS" ]; then IDS=$(_az GET "$R_ORG/_apis/connectionData" | jq -r '.authenticatedUser.id'); WHO=", you (the PAT owner)"; fi
      APPROVERS=$(printf '%s\n' $IDS | jq -R '{id:.}' | jq -s .)
      BODY=$(jq -n --argjson ap "$APPROVERS" --arg id "$EID" --arg n "$NAME" '
          {type:{id:"8C6F20A7-A545-4486-9777-F762FAFE0D4D", name:"Approval"},
           settings:{approvers:$ap, executionOrder:"anyOrder", minRequiredApprovers:0,
                     instructions:"DevPilot: approve only after the previous stage is verified.", blockedApprovers:[]},
           resource:{type:"environment", id:$id, name:$n}, timeout:43200}')
      CID=$(_az GET "$RP/_apis/pipelines/checks/configurations?resourceType=environment&resourceId=$EID&api-version=7.1-preview.1" \
        | jq -r '[.value[] | select(.type.name == "Approval")] | first | .id // empty')
      if [ -z "$CID" ]; then
        _az POST "$RP/_apis/pipelines/checks/configurations?api-version=7.1-preview.1" "$BODY" >/dev/null || exit 1
      elif [ -n "${DEVPILOT_APPROVERS:-}" ]; then
        _az PATCH "$RP/_apis/pipelines/checks/configurations/$CID?api-version=7.1-preview.1" "$(echo "$BODY" | jq --argjson c "$CID" '. + {id:$c}')" >/dev/null || exit 1
      else
        echo "  ✅ environment $NAME — approval already configured"; exit 0
      fi
      echo "  ✅ environment $NAME — approval by${WHO#,}"
    else
      echo "  ✅ environment $NAME"
    fi
    ;;

  *) echo "Usage: azdo.sh <ping|new|show|search|list|status|comment|describe|link|url|ref|sprint-*|pr-*|ci|repo-id|pipeline-ensure|protect|env-setup> …" >&2; exit 2 ;;
esac
