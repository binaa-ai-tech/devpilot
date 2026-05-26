#!/usr/bin/env bash
# =============================================================================
# checkpoint.sh — State persistence engine for ceo resume
#
# Writes and reads a structured JSON checkpoint so any runner (claude, opencode,
# antigravity) can resume a task from the exact phase it left off.
#
# Usage (write):
#   bash scripts/checkpoint.sh write \
#     --key KEY-123 \
#     --slug add-user-auth \
#     --branch feature/key-123-add-user-auth \
#     --base-branch main \
#     --command "/ceo" \
#     --task "Add user authentication" \
#     --runner claude \
#     --coding-engine claude \
#     --phase-completed "implementation" \
#     --next-phase "qa" \
#     --agents-completed "ba,lead,frontend,backend" \
#     --agents-remaining "" \
#     --pause-reason "claude_limit"
#
# Usage (read):
#   bash scripts/checkpoint.sh read KEY-123 <field>
#   bash scripts/checkpoint.sh read KEY-123 next_phase
#   bash scripts/checkpoint.sh read KEY-123 slug
#
# Usage (update single field):
#   bash scripts/checkpoint.sh update KEY-123 phase_completed qa
#   bash scripts/checkpoint.sh update KEY-123 agents_completed "ba,lead,frontend,backend,qa"
#
# Usage (show):
#   bash scripts/checkpoint.sh show KEY-123
#
# Usage (find latest):
#   bash scripts/checkpoint.sh latest       → prints the KEY of the most recent in-progress task
# =============================================================================
set -euo pipefail

CHECKPOINT_DIR="docs/tasks"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

error() { echo -e "${RED}[checkpoint] ERROR:${RESET} $*" >&2; exit 1; }
info()  { echo -e "${GREEN}[checkpoint]${RESET} $*"; }

JSON_TOOL=""

require_json_tool() {
  if command -v jq >/dev/null 2>&1; then
    JSON_TOOL="jq"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    JSON_TOOL="python3"
    return
  fi
  error "checkpoint.sh requires either jq or python3. Install jq (brew/apt) or python3."
}

csv_to_json_array() {
  local csv="$1"
  if [ "$JSON_TOOL" = "jq" ]; then
    printf '%s' "$csv" | tr ',' '\n' | grep -v '^[[:space:]]*$' | jq -R . | jq -s . 2>/dev/null || echo '[]'
    return
  fi

  python3 - "$csv" <<'PY'
import json, sys
csv = sys.argv[1]
items = [x.strip() for x in csv.split(',') if x.strip()]
print(json.dumps(items))
PY
}

json_get_field() {
  local file="$1" field="$2"

  if [[ ! "$field" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    error "Invalid field name: $field"
  fi

  if [ "$JSON_TOOL" = "jq" ]; then
    jq -r --arg f "$field" 'if has($f) and .[$f] != null then .[$f] else "" end' "$file"
    return
  fi

  python3 - "$file" "$field" <<'PY'
import json, sys
path, field = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
value = data.get(field, "")
if value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False))
else:
    print(str(value))
PY
}

json_set_field() {
  local file="$1" field="$2" value="$3" tmp="$4"

  if [[ ! "$field" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    error "Invalid field name: $field"
  fi

  if [ "$JSON_TOOL" = "jq" ]; then
    jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$file" > "$tmp"
    return
  fi

  python3 - "$file" "$field" "$value" "$tmp" <<'PY'
import json, sys
src, field, value, dst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(src, 'r', encoding='utf-8') as f:
    data = json.load(f)
data[field] = value
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
}

json_append_commit() {
  local file="$1" hash="$2" tmp="$3"

  if [ "$JSON_TOOL" = "jq" ]; then
    jq --arg h "$hash" '.commits += [$h]' "$file" > "$tmp"
    return
  fi

  python3 - "$file" "$hash" "$tmp" <<'PY'
import json, sys
src, commit_hash, dst = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, 'r', encoding='utf-8') as f:
    data = json.load(f)
commits = data.get('commits')
if not isinstance(commits, list):
    commits = []
commits.append(commit_hash)
data['commits'] = commits
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
}

json_pretty_print() {
  local file="$1"
  if [ "$JSON_TOOL" = "jq" ]; then
    jq '.' "$file"
  else
    python3 -m json.tool "$file"
  fi
}

checkpoint_path() {
  echo "${CHECKPOINT_DIR}/${1}-checkpoint.json"
}

# ── Write ─────────────────────────────────────────────────────────────────────
cmd_write() {
  require_json_tool

  local key="" slug="" branch="" base_branch="" command="" task=""
  local runner="" coding_engine="" phase_completed="" next_phase=""
  local agents_completed="" agents_remaining="" pause_reason="none"

  while [ $# -gt 0 ]; do
    case "$1" in
      --key)             key="$2";              shift 2 ;;
      --slug)            slug="$2";             shift 2 ;;
      --branch)          branch="$2";           shift 2 ;;
      --base-branch)     base_branch="$2";      shift 2 ;;
      --command)         command="$2";          shift 2 ;;
      --task)            task="$2";             shift 2 ;;
      --runner)          runner="$2";           shift 2 ;;
      --coding-engine)   coding_engine="$2";    shift 2 ;;
      --phase-completed) phase_completed="$2";  shift 2 ;;
      --next-phase)      next_phase="$2";       shift 2 ;;
      --agents-completed) agents_completed="$2"; shift 2 ;;
      --agents-remaining) agents_remaining="$2"; shift 2 ;;
      --pause-reason)    pause_reason="$2";     shift 2 ;;
      *) error "Unknown flag: $1" ;;
    esac
  done

  [ -z "$key" ] && error "--key is required"

  mkdir -p "$CHECKPOINT_DIR"
  local now
  now=$(date '+%Y-%m-%d %H:%M:%S')
  local file
  file=$(checkpoint_path "$key")

  # Convert comma-separated lists to JSON arrays
  agents_completed_json=$(csv_to_json_array "$agents_completed")
  agents_remaining_json=$(csv_to_json_array "$agents_remaining")

  # Gather current git commits on feature branch
  local commits_json='[]'
  if git rev-parse --git-dir &>/dev/null 2>&1 && [ -n "$base_branch" ]; then
    commits_json=$(git log "${base_branch}..HEAD" --oneline 2>/dev/null \
      | awk '{print $1}' | head -20 \
      | if [ "$JSON_TOOL" = "jq" ]; then jq -R . | jq -s . 2>/dev/null; else python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))'
        fi || echo '[]')
  fi

  if [ "$JSON_TOOL" = "jq" ]; then
    jq -n \
      --arg schema_version "2" \
      --arg key "$key" \
      --arg slug "$slug" \
      --arg branch "$branch" \
      --arg base_branch "$base_branch" \
      --arg command "$command" \
      --arg task "$task" \
      --arg runner "$runner" \
      --arg coding_engine "$coding_engine" \
      --arg phase_completed "$phase_completed" \
      --arg next_phase "$next_phase" \
      --argjson agents_completed "$agents_completed_json" \
      --argjson agents_remaining "$agents_remaining_json" \
      --argjson commits "$commits_json" \
      --arg pause_reason "$pause_reason" \
      --arg paused_at "$now" \
      '{
        schema_version: $schema_version,
        key: $key,
        slug: $slug,
        branch: $branch,
        base_branch: $base_branch,
        command: $command,
        task: $task,
        runner_tool: $runner,
        coding_engine: $coding_engine,
        phase_completed: $phase_completed,
        next_phase: $next_phase,
        agents_completed: $agents_completed,
        agents_remaining: $agents_remaining,
        commits: $commits,
        pause_reason: $pause_reason,
        paused_at: $paused_at,
        docs: {
          requirements: ("docs/requirements/" + $slug + ".md"),
          domain_model:  ("docs/domain-models/" + $slug + ".md"),
          plan:          ("docs/plans/" + $slug + ".md"),
          qa:            null,
          review:        null
        },
        fallback_prompts: {}
      }' > "$file"
  else
    python3 - "$file" "$key" "$slug" "$branch" "$base_branch" "$command" "$task" "$runner" "$coding_engine" "$phase_completed" "$next_phase" "$agents_completed_json" "$agents_remaining_json" "$commits_json" "$pause_reason" "$now" <<'PY'
import json, sys

(file_path, key, slug, branch, base_branch, command, task, runner,
 coding_engine, phase_completed, next_phase,
 agents_completed_json, agents_remaining_json, commits_json,
 pause_reason, paused_at) = sys.argv[1:]

payload = {
  "schema_version": "2",
  "key": key,
  "slug": slug,
  "branch": branch,
  "base_branch": base_branch,
  "command": command,
  "task": task,
  "runner_tool": runner,
  "coding_engine": coding_engine,
  "phase_completed": phase_completed,
  "next_phase": next_phase,
  "agents_completed": json.loads(agents_completed_json or "[]"),
  "agents_remaining": json.loads(agents_remaining_json or "[]"),
  "commits": json.loads(commits_json or "[]"),
  "pause_reason": pause_reason,
  "paused_at": paused_at,
  "docs": {
    "requirements": f"docs/requirements/{slug}.md",
    "domain_model": f"docs/domain-models/{slug}.md",
    "plan": f"docs/plans/{slug}.md",
    "qa": None,
    "review": None,
  },
  "fallback_prompts": {},
}

with open(file_path, "w", encoding="utf-8") as f:
  json.dump(payload, f, indent=2, ensure_ascii=False)
  f.write("\n")
PY
  fi

  info "Checkpoint written: $file"
}

# ── Read a single field ───────────────────────────────────────────────────────
cmd_read() {
  require_json_tool
  local key="${1:-}" field="${2:-}"
  [ -z "$key" ] || [ -z "$field" ] && error "Usage: checkpoint.sh read <KEY> <field>"

  local file
  file=$(checkpoint_path "$key")
  [ -f "$file" ] || error "No checkpoint found for $key — run checkpoint.sh write first"

  json_get_field "$file" "$field"
}

# ── Update a single field ─────────────────────────────────────────────────────
cmd_update() {
  require_json_tool
  local key="${1:-}" field="${2:-}" value="${3:-}"
  [ -z "$key" ] || [ -z "$field" ] || [ -z "$value" ] && \
    error "Usage: checkpoint.sh update <KEY> <field> <value>"

  local file
  file=$(checkpoint_path "$key")
  [ -f "$file" ] || error "No checkpoint found for $key"

  local tmp="${file}.tmp"
  json_set_field "$file" "$field" "$value" "$tmp"
  mv "$tmp" "$file"
  info "Updated ${key}.${field} = ${value}"
}

# ── Append a commit hash ───────────────────────────────────────────────────────
cmd_add_commit() {
  require_json_tool
  local key="${1:-}" hash="${2:-}"
  [ -z "$key" ] || [ -z "$hash" ] && error "Usage: checkpoint.sh add-commit <KEY> <hash>"

  local file
  file=$(checkpoint_path "$key")
  [ -f "$file" ] || error "No checkpoint found for $key"

  local tmp="${file}.tmp"
  json_append_commit "$file" "$hash" "$tmp"
  mv "$tmp" "$file"
  info "Added commit $hash to checkpoint $key"
}

# ── Show full checkpoint ───────────────────────────────────────────────────────
cmd_show() {
  require_json_tool
  local key="${1:-}"
  [ -z "$key" ] && error "Usage: checkpoint.sh show <KEY>"

  local file
  file=$(checkpoint_path "$key")
  [ -f "$file" ] || error "No checkpoint found for $key"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Checkpoint — $key"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  json_pretty_print "$file"
  echo ""
}

# ── Find the latest in-progress task ─────────────────────────────────────────
cmd_latest() {
  require_json_tool
  mkdir -p "$CHECKPOINT_DIR"

  local latest_file=""
  local latest_time=0

  for f in "$CHECKPOINT_DIR"/*-checkpoint.json; do
    [ -f "$f" ] || continue
    local mtime
    mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
    if [ "$mtime" -gt "$latest_time" ]; then
      latest_time="$mtime"
      latest_file="$f"
    fi
  done

  if [ -z "$latest_file" ]; then
    echo ""
    return
  fi

  json_get_field "$latest_file" "key"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  write)      cmd_write "$@" ;;
  read)       cmd_read "$@" ;;
  update)     cmd_update "$@" ;;
  add-commit) cmd_add_commit "$@" ;;
  show)       cmd_show "$@" ;;
  latest)     cmd_latest ;;
  *)
    echo ""
    echo "checkpoint.sh — task state engine"
    echo ""
    echo "  write   --key KEY --slug SLUG --branch BRANCH ..."
    echo "  read    KEY field"
    echo "  update  KEY field value"
    echo "  show    KEY"
    echo "  latest  (print KEY of most recent checkpoint)"
    echo ""
    exit 1
    ;;
esac
