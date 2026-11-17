#!/usr/bin/env bash
# =============================================================================
# verify.sh — prove a change by running it: start the app, drive the journeys the
# diff touches in a real browser, keep the evidence. The skill that governs it is
# .claude/skills/verify-change/SKILL.md. (smoke.sh is the post-deploy health check
# of an environment — a different thing.)
#
#   verify.sh run <KEY> [--all] [--repeat N] [--base <branch>]   start → journeys → report → stop
#   verify.sh features [--all] [--base <branch>]                  features the diff touches (id<TAB>title)
#   verify.sh map-draft                                           write a DRAFT docs/feature-map.md
#   verify.sh skip <KEY> "<reason>"                               record "no runtime surface" + why
#   verify.sh gate <KEY>                                          exit 0 only with a passing report
#   verify.sh config                                              show the resolved settings
#
# Settings — environment variables win, then .devpilot/config.sh (devpilot-config.sh):
#   VERIFY_FE_CMD      start the frontend            e.g. "npm --prefix web start"
#   VERIFY_FE_URL      frontend URL to wait for      e.g. http://localhost:4200
#   VERIFY_API_CMD     start the API                 e.g. "dotnet run --project src/Api"
#   VERIFY_API_HEALTH  API health URL to wait for    e.g. http://localhost:5080/health
#   VERIFY_TIMEOUT     seconds to wait for health    (default 120)
#   VERIFY_E2E_DIR     where the journeys live       (default: the folder holding playwright.config.*)
#   VERIFY_E2E_CMD     journey runner; `--grep <journey>` is appended per feature
#                      (default "npx playwright test --retries=0 --reporter=line")
# A service that already answers on its URL is reused and left running; one this script
# starts is always stopped — on success, failure or Ctrl-C.
#
# Feature map (docs/feature-map.md) — one entry per feature, also the grading rubric:
#   ## F-01 · Export orders as CSV
#   - Route: /orders
#   - Files: web/src/app/orders/*, api/Controllers/Orders*     (globs; "*" also crosses "/")
#   - Steps: open Orders → click "Export CSV"
#   - Selectors: getByRole('button', { name: 'Export CSV' })
#   - Expected: orders-<date>.csv downloads and the toast "Export ready" shows
#   - Journey: @F-01                                           (optional; default @<id>)
# A journey passes only when its runner exits 0 (the Expected result was asserted) AND it
# left at least one screenshot in $VERIFY_EVIDENCE_DIR.
#
# Evidence: docs/tasks/<KEY>-evidence/<feature>/ (screenshots, console-errors.log,
# network-failures.log, journey.log) + docs/tasks/<KEY>-evidence/verify-report.md.
# Exit: 0 pass / no runtime surface · 1 fail · 2 usage or not configured · 3 draft map written
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
DIR="$ROOT/scripts"
MAP="docs/feature-map.md"
DRAFT_MARK="DRAFT — needs owner review"

usage() { sed -n '8,13p' "$0" | sed 's/^# \{0,3\}//'; exit 2; }

# cfgv <NAME> [default] — environment → .devpilot/config.sh → default
cfgv() {
  local v="${!1:-}"
  if [ -z "$v" ] && [ -f .devpilot/config.sh ] && [ -f "$DIR/devpilot-config.sh" ]; then
    v=$(bash "$DIR/devpilot-config.sh" get "$1" 2>/dev/null || true)
  fi
  printf '%s' "${v:-${2:-}}"
}

base_branch() {
  local b; b=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  printf '%s' "${b:-develop}"
}

load_config() {
  FE_CMD=$(cfgv VERIFY_FE_CMD);   FE_URL=$(cfgv VERIFY_FE_URL)
  API_CMD=$(cfgv VERIFY_API_CMD); API_HEALTH=$(cfgv VERIFY_API_HEALTH)
  TIMEOUT=$(cfgv VERIFY_TIMEOUT 120)
  E2E_CMD=$(cfgv VERIFY_E2E_CMD "npx playwright test --retries=0 --reporter=line")
  E2E_DIR=$(cfgv VERIFY_E2E_DIR)
  if [ -z "$E2E_DIR" ]; then
    E2E_DIR=$(git ls-files 2>/dev/null | grep -E '(^|/)playwright\.config\.(ts|js|mjs)$' | head -1)
    E2E_DIR=$(dirname "${E2E_DIR:-./x}")
  fi
  case "$TIMEOUT" in ''|*[!0-9]*) echo "❌ VERIFY_TIMEOUT must be a number of seconds (got '$TIMEOUT')" >&2; exit 2 ;; esac
}

# ── Feature map ───────────────────────────────────────────────────────────────
# map_rows → id<TAB>title<TAB>files<TAB>expected<TAB>journey  (one line per entry)
map_rows() {
  [ -f "$MAP" ] || return 0
  awk '
    function flush() { if (id != "") printf "%s\t%s\t%s\t%s\t%s\n", id, title, files, expected, (journey == "" ? "@" id : journey) }
    function val(s) { sub(/^- [A-Za-z]+:[[:space:]]*/, "", s); sub(/[[:space:]]+\(optional.*$/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^## / { flush(); line = $0; sub(/^## +/, "", line); id = line; sub(/[[:space:]].*$/, "", id)
             title = line; sub(/^[^[:space:]]+[[:space:]]*(·|-|—|:)?[[:space:]]*/, "", title)
             files = ""; expected = ""; journey = ""; next }
    /^- Files:/    { files = val($0) }
    /^- Expected:/ { expected = val($0) }
    /^- Journey:/  { journey = val($0) }
    END { flush() }
  ' "$MAP"
}

map_is_draft() { [ -f "$MAP" ] && grep -qF "$DRAFT_MARK" "$MAP"; }

changed_files() {  # changed_files <base>
  local ref="$1"
  git rev-parse --verify --quiet "origin/$ref" >/dev/null 2>&1 && ref="origin/$ref"
  {
    git rev-parse --verify --quiet "$ref" >/dev/null 2>&1 && git diff --name-only "$ref"...HEAD 2>/dev/null
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u | grep -v '^$' || true
}

# True when a changed file can change what a user (or API caller) observes at runtime.
is_runtime_file() {
  case "$1" in
    docs/*|*.md|.claude/*|.devpilot/*|.github/*) return 1 ;;
    *.spec.ts|*.test.ts|*.test.tsx|*.e2e.ts|*Tests.cs|*Test.cs|*/test_*.py|test_*.py|*_test.py) return 1 ;;
    e2e/*|*/e2e/*|*/tests/*|tests/*|*.Tests/*) return 1 ;;
    *.ts|*.tsx|*.js|*.jsx|*.html|*.scss|*.css|*.cs|*.cshtml|*.razor|*.py|*.sql) return 0 ;;
  esac
  return 1
}

# file_matches <file> "<glob>, <glob>" — bash patterns, so "*" also crosses "/"
file_matches() {
  local f="$1" g rest="$2"
  while [ -n "$rest" ]; do
    g="${rest%%,*}"; [ "$g" = "$rest" ] && rest="" || rest="${rest#*,}"
    g="${g#"${g%%[![:space:]]*}"}"; g="${g%"${g##*[![:space:]]}"}"
    g="${g//\`/}"
    [ -z "$g" ] && continue
    # shellcheck disable=SC2053  # unquoted on purpose: the entry is a glob
    [[ "$f" == $g ]] && return 0
  done
  return 1
}

# select_features <base> <all:0|1> → sets SELECTED (map rows), UNMAPPED (runtime files no feature owns)
select_features() {
  local base="$1" all="$2" rows changed f row files hit
  rows=$(map_rows); changed=$(changed_files "$base")
  SELECTED=""; UNMAPPED=""; RUNTIME_COUNT=0
  if [ "$all" = 1 ]; then SELECTED="$rows"; fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_runtime_file "$f" || continue
    RUNTIME_COUNT=$((RUNTIME_COUNT + 1)); hit=0
    while IFS= read -r row; do
      [ -z "$row" ] && continue
      files=$(printf '%s' "$row" | cut -f3)
      if file_matches "$f" "$files"; then
        hit=1
        case "
$SELECTED
" in *"
$row
"*) : ;; *) SELECTED="${SELECTED:+$SELECTED
}$row" ;; esac
      fi
    done <<EOF
$rows
EOF
    [ "$hit" = 0 ] && UNMAPPED="${UNMAPPED:+$UNMAPPED
}$f"
  done <<EOF
$changed
EOF
}

# ── Draft map ─────────────────────────────────────────────────────────────────
cmd_map_draft() {
  if [ -f "$MAP" ]; then echo "ℹ️  $MAP exists — not overwritten"; return 0; fi
  mkdir -p docs
  local n=0 f title routes_file route dir
  {
    echo "# Feature map"
    echo ""
    echo "> **$DRAFT_MARK.** Generated by \`scripts/verify.sh map-draft\` from \`docs/requirements/\` and the"
    echo "> Angular routes. Fill in each entry, delete this note once an owner has reviewed it."
    echo "> One entry per feature as the user sees it. It is also the grading rubric: a journey"
    echo "> passes only if its **Expected** result is observed. Format: \`scripts/verify.sh\` header."
    echo ""
    for f in docs/requirements/*.md; do
      [ -f "$f" ] || continue
      title=$(grep -m1 '^# ' "$f" | sed 's/^# *//; s/^Requirements:[[:space:]]*//')
      n=$((n + 1))
      printf '## F-%02d · %s\n' "$n" "${title:-$(basename "$f" .md)}"
      echo "- Route: TODO"
      echo "- Files: TODO"
      echo "- Steps: TODO — from the acceptance criteria in \`$f\`"
      echo "- Selectors: TODO"
      echo "- Expected: TODO"
      echo ""
    done
    while IFS= read -r routes_file; do
      [ -f "$routes_file" ] || continue
      dir=$(dirname "$routes_file")
      for route in $(grep -oE "path:[[:space:]]*['\"][^'\"]*['\"]" "$routes_file" | sed -E "s/path:[[:space:]]*['\"]//; s/['\"]$//" | grep -v -e '^$' -e '^\*\*$' | sort -u); do
        n=$((n + 1))
        printf '## F-%02d · Screen /%s\n' "$n" "$route"
        echo "- Route: /$route"
        echo "- Files: $dir/*"
        echo "- Steps: TODO"
        echo "- Selectors: TODO"
        echo "- Expected: TODO"
        echo ""
      done
    done <<EOF
$(git ls-files 2>/dev/null | grep -E '(\.routes\.ts|-routing\.module\.ts|routes\.ts)$' || true)
EOF
  } > "$MAP"
  echo "✅ wrote $MAP ($n entr$([ "$n" = 1 ] && echo y || echo ies)) — marked '$DRAFT_MARK'; flag it in the PR"
}

# ── Services ──────────────────────────────────────────────────────────────────
STARTED_PIDS=""
is_up() {
  local code; code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null)
  case "$code" in 2*|3*) return 0 ;; esac
  return 1
}

stop_services() {
  local pid i
  for pid in $STARTED_PIDS; do
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in $STARTED_PIDS; do
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 0.5; i=$((i + 1)); done
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  [ -n "$STARTED_PIDS" ] && echo "  ✅ services stopped"
  STARTED_PIDS=""
}

# start_service <label> <cmd> <url> <log> → sets SVC_STATE (started|reused|none); 1 on failure
start_service() {
  local label="$1" cmd="$2" url="$3" log="$4" pid waited=0
  SVC_STATE="none"
  [ -z "$cmd" ] && [ -z "$url" ] && return 0
  if [ -n "$url" ] && is_up "$url"; then
    SVC_STATE="reused"; echo "  ✅ $label already answers on $url — reused (left running)"; return 0
  fi
  if [ -z "$cmd" ]; then
    echo "  ❌ $label is not answering on $url and no start command is set"; return 1
  fi
  if [ -z "$url" ]; then
    echo "  ❌ $label has a start command but no URL to wait for"; return 1
  fi
  mkdir -p .devpilot/logs
  set -m                                    # own process group, so stop reaches every child
  bash -c "$cmd" > "$log" 2>&1 &
  pid=$!
  set +m
  STARTED_PIDS="$STARTED_PIDS $pid"
  while [ "$waited" -lt "$TIMEOUT" ]; do
    if is_up "$url"; then
      SVC_STATE="started"; echo "  ✅ $label up on $url (${waited}s)"; return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "  ❌ $label exited before answering on $url — log: $log"; tail -5 "$log" 2>/dev/null | sed 's/^/       /'; return 1
    fi
    sleep 1; waited=$((waited + 1))
  done
  echo "  ❌ $label did not answer on $url within ${TIMEOUT}s — log: $log"
  return 1
}

# ── Report ────────────────────────────────────────────────────────────────────
evidence_dir() { printf 'docs/tasks/%s-evidence' "$1"; }
count_lines() { [ -s "$1" ] && grep -c '' "$1" || echo 0; }
md_cell() { printf '%s' "$1" | tr '|\t' '/ ' | cut -c1-140; }

report_header() {  # report_header <KEY> <base>
  local dirty=""
  [ -n "$(git status --porcelain 2>/dev/null | head -1)" ] && dirty=" + uncommitted changes"
  echo "# Verify report — $1"
  echo ""
  echo "- Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ') · Branch: $(git branch --show-current 2>/dev/null) · Commit: $(git rev-parse --short HEAD 2>/dev/null)$dirty · Base: $2"
}

cmd_skip() {
  local key="$1" reason="$2" ev
  [ -z "$reason" ] && { echo "❌ a reason is required: verify.sh skip <KEY> \"<why this change has no runtime surface>\"" >&2; exit 2; }
  ev=$(evidence_dir "$key"); mkdir -p "$ev"
  {
    report_header "$key" "$(base_branch)"
    echo ""
    echo "Result: ⏭ NO RUNTIME SURFACE"
    echo "Reason: $reason"
  } > "$ev/verify-report.md"
  echo "✅ recorded: no runtime surface — $ev/verify-report.md"
}

cmd_gate() {
  local rep; rep="$(evidence_dir "$1")/verify-report.md"
  if [ ! -f "$rep" ]; then
    echo "❌ verify gate: no $rep — run: bash scripts/verify.sh run $1   (docs-only change: bash scripts/verify.sh skip $1 \"<reason>\")"
    return 1
  fi
  if grep -q '^Result: ✅ PASS' "$rep"; then echo "✅ verify gate: PASS ($rep)"; return 0; fi
  if grep -q '^Result: ⏭ NO RUNTIME SURFACE' "$rep" && grep -qE '^Reason: .*[^[:space:]]' "$rep"; then
    echo "✅ verify gate: no runtime surface — $(grep -m1 '^Reason: ' "$rep" | sed 's/^Reason: //')"; return 0
  fi
  echo "❌ verify gate: $rep is not a pass — $(grep -m1 '^Result: ' "$rep" || echo 'no Result line')"
  return 1
}

# ── Run ───────────────────────────────────────────────────────────────────────
cmd_run() {
  local key="$1" all="$2" repeat="$3" base="$4"
  local ev rep rows row id title expected journey fdir rc run outcome first_outcome="" stable=1
  local shots cons nets status fail=0 table="" fe_state api_state abs_ev
  ev=$(evidence_dir "$key"); rep="$ev/verify-report.md"
  load_config
  echo "── verify $key (vs $base) ───────────────────────────"

  if [ ! -f "$MAP" ]; then
    cmd_map_draft
    echo "❌ no feature map existed. A draft is in $MAP: fill Files / Steps / Selectors / Expected for the"
    echo "   features this change touches, then re-run. The draft stays flagged until an owner reviews it."
    exit 3
  fi

  select_features "$base" "$all"
  rows="$SELECTED"
  mkdir -p "$ev"

  if [ -z "$rows" ] && [ "$RUNTIME_COUNT" = 0 ]; then
    cmd_skip "$key" "the diff against $base changes no runtime file (docs, config, tests or tooling only)"
    return 0
  fi

  if [ -n "$UNMAPPED" ] && [ "$all" != 1 ]; then
    {
      report_header "$key" "$base"
      echo ""
      echo "Changed runtime files that no feature in \`$MAP\` owns:"
      printf '%s\n' "$UNMAPPED" | sed 's/^/- `/; s/$/`/'
      echo ""
      echo "Result: ❌ FAIL — unmapped runtime changes"
    } > "$rep"
    echo "  ❌ changed runtime files map to no feature — add them to a 'Files:' line in $MAP:"
    printf '%s\n' "$UNMAPPED" | sed 's/^/       /'
    echo "──────────────────────────────────────────────────────"
    return 1
  fi

  if [ -z "$FE_URL" ] && [ -z "$API_HEALTH" ]; then
    echo "  ❌ verify is not configured — set at least VERIFY_FE_URL or VERIFY_API_HEALTH (and the start commands):"
    echo "       bash scripts/devpilot-config.sh set verify_fe_cmd=\"npm --prefix web start\""
    echo "       bash scripts/devpilot-config.sh set verify_fe_url=http://localhost:4200"
    exit 2
  fi

  trap 'stop_services' EXIT
  trap 'stop_services; exit 130' INT TERM
  start_service "API" "$API_CMD" "$API_HEALTH" ".devpilot/logs/verify-api.log" || fail=1; api_state="$SVC_STATE"
  [ "$fail" = 0 ] && { start_service "web" "$FE_CMD" "$FE_URL" ".devpilot/logs/verify-web.log" || fail=1; }; fe_state="${SVC_STATE:-none}"

  if [ "$fail" = 1 ]; then
    {
      report_header "$key" "$base"
      echo ""
      echo "Result: ❌ FAIL — services did not start (logs: .devpilot/logs/verify-*.log)"
    } > "$rep"
    echo "──────────────────────────────────────────────────────"
    return 1
  fi

  abs_ev="$ROOT/$ev"
  run=1
  while [ "$run" -le "$repeat" ]; do
    outcome=""; table=""
    while IFS= read -r row; do
      [ -z "$row" ] && continue
      id=$(printf '%s' "$row" | cut -f1); title=$(printf '%s' "$row" | cut -f2)
      expected=$(printf '%s' "$row" | cut -f4); journey=$(printf '%s' "$row" | cut -f5)
      fdir="$ev/$id"; rm -rf "$fdir"; mkdir -p "$fdir"
      ( cd "$E2E_DIR" 2>/dev/null || exit 127
        VERIFY_EVIDENCE_DIR="$abs_ev/$id" VERIFY_FEATURE="$id" VERIFY_FE_URL="$FE_URL" VERIFY_API_HEALTH="$API_HEALTH" \
          bash -c "$E2E_CMD --grep \"\$1\"" _ "$journey" ) > "$fdir/journey.log" 2>&1
      rc=$?
      shots=$(find "$fdir" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')
      cons=$(count_lines "$fdir/console-errors.log"); nets=$(count_lines "$fdir/network-failures.log")
      if [ "$rc" != 0 ]; then status="❌ fail — expected result not observed (exit $rc, see $id/journey.log)"; fail=1; outcome="$outcome $id=fail"
      elif [ "$shots" = 0 ]; then status="❌ fail — passed but left no screenshot in the evidence folder"; fail=1; outcome="$outcome $id=noevidence"
      else status="✅ pass"; outcome="$outcome $id=pass"; fi
      echo "  ${status%% —*} $id · $title"
      table="$table| $id · $(md_cell "$title") | \`$(md_cell "$journey")\` | $(md_cell "${expected:-—}") | $status | $shots screenshot(s) · $cons console error(s) · $nets failed request(s) |
"
    done <<EOF
$rows
EOF
    [ "$run" = 1 ] && first_outcome="$outcome"
    [ "$outcome" = "$first_outcome" ] || stable=0
    run=$((run + 1))
  done

  stop_services; trap - EXIT INT TERM

  {
    report_header "$key" "$base"
    if map_is_draft; then echo "- Feature map: \`$MAP\` — ⚠️ $DRAFT_MARK (flag it in the PR)"
    else echo "- Feature map: \`$MAP\`"; fi
    echo "- Services: API ${API_HEALTH:-—} ($api_state) · web ${FE_URL:-—} ($fe_state)"
    echo "- Runs: $repeat$([ "$repeat" -gt 1 ] && { [ "$stable" = 1 ] && echo ' (identical)' || echo ' (results differed between runs)'; })"
    [ -n "$UNMAPPED" ] && { echo "- ⚠️ Changed runtime files no feature owns: $(printf '%s' "$UNMAPPED" | tr '\n' ' ')"; }
    echo ""
    echo "| Feature | Journey | Expected result | Result | Evidence |"
    echo "|---------|---------|-----------------|--------|----------|"
    printf '%s' "$table"
    echo ""
    if [ "$stable" = 0 ]; then echo "Result: ❌ UNSTABLE — the same journeys gave different results across $repeat runs; fix the harness or the journey"
    elif [ "$fail" = 1 ]; then echo "Result: ❌ FAIL"
    else echo "Result: ✅ PASS"; fi
  } > "$rep"

  echo "  report: $rep"
  echo "──────────────────────────────────────────────────────"
  [ "$stable" = 1 ] && [ "$fail" = 0 ]
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
CMD="${1:-}"; [ $# -gt 0 ] && shift
KEY=""; ALL=0; REPEAT=1; BASE=""; REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)    ALL=1; shift ;;
    --repeat) REPEAT="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --base)   BASE="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    -*)       echo "❌ unknown option: $1" >&2; usage ;;
    *)        if [ -z "$KEY" ]; then KEY="$1"; else REASON="$1"; fi; shift ;;
  esac
done
BASE="${BASE:-$(base_branch)}"
case "$REPEAT" in ''|*[!0-9]*|0) echo "❌ --repeat needs a number ≥ 1" >&2; exit 2 ;; esac
need_key() {
  case "$KEY" in
    '') echo "❌ a work item key is required (e.g. MSK-12)" >&2; usage ;;
    *[!A-Za-z0-9._-]*) echo "❌ invalid key '$KEY' (letters, digits, . _ - only)" >&2; exit 2 ;;
  esac
}

case "$CMD" in
  run)       need_key; cmd_run "$KEY" "$ALL" "$REPEAT" "$BASE" ;;
  features)  select_features "$BASE" "$ALL"
             [ -n "$SELECTED" ] && printf '%s\n' "$SELECTED" | cut -f1,2
             [ -n "$UNMAPPED" ] && printf '%s\n' "$UNMAPPED" | sed 's/^/unmapped\t/' >&2
             exit 0 ;;
  map-draft) cmd_map_draft ;;
  skip)      need_key; cmd_skip "$KEY" "$REASON" ;;
  gate)      need_key; cmd_gate "$KEY" ;;
  config)    load_config
             echo "VERIFY_FE_CMD=$FE_CMD"; echo "VERIFY_FE_URL=$FE_URL"
             echo "VERIFY_API_CMD=$API_CMD"; echo "VERIFY_API_HEALTH=$API_HEALTH"
             echo "VERIFY_TIMEOUT=$TIMEOUT"; echo "VERIFY_E2E_DIR=$E2E_DIR"; echo "VERIFY_E2E_CMD=$E2E_CMD"
             echo "FEATURE_MAP=$MAP ($([ -f "$MAP" ] && { map_is_draft && echo draft || echo present; } || echo missing))" ;;
  *)         usage ;;
esac
