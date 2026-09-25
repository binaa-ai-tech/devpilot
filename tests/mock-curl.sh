#!/usr/bin/env bash
# tests/mock-curl.sh — stands in for curl so the Jira / Azure DevOps / GitHub
# backends can be tested offline. Installed as `curl` on PATH by tests/run.sh.
#
# Every call is appended to $MOCK_LOG as:  METHOD<TAB>URL<TAB>DATA
# The response body is chosen by URL (and method) below; the status code comes
# from $MOCK_CODE (default 200). Honors -o <file> and -w '%{http_code}'.
set -u
OUT=""; METHOD="GET"; DATA=""; URL=""; WFMT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    -X|--request) METHOD="$2"; shift 2 ;;
    --data|-d) DATA="$2"; [ "$METHOD" = "GET" ] && METHOD="POST"; shift 2 ;;
    -w) WFMT="$2"; shift 2 ;;
    --user|-u|-H|--header|--max-time|--url) [ "$1" = "--url" ] && URL="$2"; shift 2 ;;
    -s|-S|-sS|-f|-L) shift ;;
    http*) URL="$1"; shift ;;
    *) shift ;;
  esac
done
# Whitespace is stripped from the body so tests can match compact JSON.
printf '%s\t%s\t%s\n' "$METHOD" "$URL" "$(printf '%s' "$DATA" | tr -d ' \n')" >> "${MOCK_LOG:-/dev/null}"

body() {
  case "$METHOD $URL" in
    # ── Jira ────────────────────────────────────────────────────────────────
    "GET "*/rest/api/3/myself*)                 echo '{"accountId":"a1"}' ;;
    "GET "*/rest/api/3/project/*/versions*)     echo '[]' ;;
    "GET "*/rest/api/3/project/*)               echo '{"key":"MSK"}' ;;
    "POST "*/rest/api/3/issue)                  echo '{"key":"MSK-101"}' ;;
    "POST "*/rest/api/3/search/jql)             echo '{"issues":[{"key":"MSK-7","fields":{"summary":"Export orders as CSV","issuetype":{"name":"Story"},"status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},"parent":{"key":"MSK-1"}}}]}' ;;
    "GET "*/rest/api/3/issue/*/transitions)     echo '{"transitions":[{"id":"11","name":"Start","to":{"name":"In Progress","statusCategory":{"key":"indeterminate"}}},{"id":"31","name":"Ship it","to":{"name":"Done","statusCategory":{"key":"done"}}}]}' ;;
    "POST "*/rest/api/3/issue/*/transitions)    echo '' ;;
    "GET "*/rest/agile/1.0/board*)              echo '{"values":[{"id":5}]}' ;;
    "POST "*/rest/agile/1.0/sprint)             echo '{"id":42}' ;;
    "GET "*/rest/agile/1.0/sprint/*)            echo '{"state":"active"}' ;;
    "POST "*/rest/agile/1.0/sprint/*)           echo '{}' ;;
    # ── Azure DevOps ────────────────────────────────────────────────────────
    "GET "*/_apis/projects/*)                   echo '{"name":"Shop"}' ;;
    "GET "*/_apis/projects\?*)                  echo '{"value":[{"name":"Shop"}]}' ;;
    "GET "*/_apis/git/repositories\?*)          echo "{\"value\":[{\"name\":\"web\",\"defaultBranch\":\"refs/heads/main\",\"remoteUrl\":\"${MOCK_REPO_URL:-}\"}]}" ;;
    "GET "*/_apis/wit/workitemtypes/*/states*)  echo '{"value":[{"name":"New","category":"Proposed"},{"name":"Active","category":"InProgress"},{"name":"Closed","category":"Completed"}]}' ;;
    "GET "*/_apis/wit/workitemtypes*)           echo '{"value":[{"name":"Epic"},{"name":"User Story"},{"name":"Bug"},{"name":"Task"}]}' ;;
    "PATCH "*/_apis/wit/workitems/*)            echo '{"id":345}' ;;
    "GET "*/_apis/wit/workitems/*)              echo '{"id":345,"fields":{"System.WorkItemType":"User Story","System.State":"New","System.Title":"t"}}' ;;
    "POST "*/_apis/wit/wiql*)                   if [ -n "${MOCK_WIQL:-}" ]; then echo "$MOCK_WIQL"; else echo '{"workItems":[]}'; fi ;;
    "POST "*/_apis/wit/classificationnodes/*)   echo '{"identifier":"guid-1","name":"S1"}' ;;
    "POST "*/_apis/work/teamsettings/iterations*) echo '{}' ;;
    "GET "*/_apis/work/teamsettings/iterations*)  echo '{"value":[{"name":"Sprint 9"}]}' ;;
    "GET "*/_apis/wit/classificationnodes/*)    echo '{"attributes":{"startDate":"2026-09-01T00:00:00Z"}}' ;;
    "PATCH "*/_apis/wit/classificationnodes/*)  echo '{}' ;;
    "POST "*/pullrequests\?*)                   echo '{"pullRequestId":77}' ;;
    "GET "*/pullrequests/77\?*)                 # active until the auto-complete PATCH arrives
                                                ST=active; [ -f "${MOCK_LOG:-/tmp/x}.merged" ] && ST=completed
                                                echo "{\"pullRequestId\":77,\"status\":\"$ST\",\"mergeStatus\":\"succeeded\",\"title\":\"t\",\"createdBy\":{\"id\":\"u1\"},\"repository\":{\"project\":{\"id\":\"p1\"}}}" ;;
    "PATCH "*/pullrequests/77\?*)               touch "${MOCK_LOG:-/tmp/x}.merged"; echo '{}' ;;
    "GET "*/_apis/policy/evaluations*)          if [ -n "${MOCK_NO_POLICY:-}" ]; then echo '{"value":[]}'
                                                else echo '{"value":[{"status":"approved","configuration":{"isBlocking":true,"type":{"id":"0609b952-1397-4640-95ec-e00a01b2c241","displayName":"Build"}}}]}'; fi ;;
    "GET "*/_apis/git/policy/configurations*)   echo '{"value":[]}' ;;
    "POST "*/_apis/policy/configurations*)      echo '{"id":1}' ;;
    "PUT "*/_apis/policy/configurations/*)      echo '{"id":1}' ;;
    "GET "*/_apis/pipelines\?*)                 echo '{"value":[]}' ;;
    "POST "*/_apis/pipelines\?*)                echo '{"id":55}' ;;
    "GET "*/_apis/distributedtask/environments*)  echo '{"value":[]}' ;;
    "POST "*/_apis/distributedtask/environments*) echo '{"id":9,"name":"x"}' ;;
    "GET "*/_apis/pipelines/checks/configurations*)  echo '{"value":[]}' ;;
    "POST "*/_apis/pipelines/checks/configurations*) echo '{"id":3}' ;;
    "GET "*/_apis/identities*)                  case "$URL" in *nobody*) echo '{"value":[]}' ;;
                                                  *) N=$(printf '%s' "$URL" | sed -E 's/.*filterValue=([^&]*).*/\1/' | tr -cd 'a-z0-9'); echo "{\"value\":[{\"id\":\"id-$N\"}]}" ;; esac ;;
    "GET "*/_apis/connectionData*)              echo '{"authenticatedUser":{"id":"me-1"}}' ;;
    "GET "*/_apis/git/repositories/*)           echo '{"id":"repo-1"}' ;;
    "DELETE "*)                                 echo '' ;;
    "POST "*hooks.example*)                     echo '{"ok":true}' ;;
    "GET "*health.example*)                     echo 'ok' ;;
    # ── GitHub ──────────────────────────────────────────────────────────────
    "GET "*/repos/*/milestones/*)               echo '{"open_issues":0}' ;;
    "POST "*/repos/*/milestones)                echo '{"number":3}' ;;
    "PATCH "*/repos/*/milestones/*)             echo '{}' ;;
    "POST "*/repos/*/issues)                    echo '{"number":12,"id":9912}' ;;
    "POST "*/repos/*/sub_issues)                echo '{}' ;;
    "GET "*/repos/*)                            echo '{"full_name":"acme/shop"}' ;;
    *)                                          echo '{}' ;;
  esac
}

CODE="${MOCK_CODE:-200}"
if [ -n "$OUT" ]; then body > "$OUT"; else body; fi
[ -n "$WFMT" ] && printf '%s' "$CODE"
exit 0
