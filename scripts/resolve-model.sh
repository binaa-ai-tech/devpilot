#!/usr/bin/env bash
# =============================================================================
# resolve-model.sh — per-task Claude model routing (power vs token cost).
#
# Classifies a task's complexity and maps it to a tier from
# project.config.md → coding_models.claude (set by model-profiles.sh):
#   power    → architectural / cross-cutting / high-risk / large changes
#   standard → normal feature & bug implementation (the default)
#   lite     → simple / mechanical / small changes
#
#   resolve-model.sh suggest "<task>"   → COMPLEXITY=<high|low>  TIER=<tier>  MODEL=<id>  SUGGEST=<text>
#   resolve-model.sh tier <power|standard|lite>  → MODEL=<id>
#   resolve-model.sh show               → the three tiers
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/project.config.md"

# two levels deep:  cfg_deep <grandparent> <parent> <key>   e.g. coding_models > claude > power
cfg_deep() {
  local gp="$1" parent="$2" key="$3"
  [ -f "$CONFIG" ] || return 0
  awk -v gp="$gp" -v parent="$parent" -v key="$key" '
    $0 ~ "^"gp":" { ingp=1; next }
    ingp && $0 ~ "^[^[:space:]]" { ingp=0 }                 # left grandparent
    ingp && $0 ~ "^[[:space:]]+"parent":" { inp=1; next }
    ingp && inp && $0 ~ "^[[:space:]][[:space:]]?[a-zA-Z]" { inp=0 }  # next sibling block
    ingp && inp && $0 ~ "^[[:space:]]+"key":" {
      sub(".*"key":[[:space:]]*", ""); sub(/#.*/, ""); gsub(/[",]/, ""); split($0,a," "); print a[1]; exit
    }
  ' "$CONFIG"
}

# normalise a complexity/tier token → power|standard|lite
norm_tier() {
  case "${1:-}" in
    power|high|complex)  echo "power"    ;;
    lite|low|simple)     echo "lite"     ;;
    *)                   echo "standard" ;;
  esac
}

tier_model() { cfg_deep coding_models claude "$(norm_tier "$1")"; }

resolve_suggest() {
  local task="${*:-}" words complex=0 tier m
  words=$(printf '%s' "$task" | wc -w | tr -d ' ')
  if printf '%s' "$task" | grep -qiE 'architect|refactor|migrat|redesign|schema|concurren|distributed|security|performance|multiple|across (layers|services)'; then
    complex=1
  fi
  [ "${words:-0}" -gt 40 ] && complex=1
  if [ "$complex" = "1" ]; then tier="power"; echo "COMPLEXITY=high"; else tier="standard"; echo "COMPLEXITY=low"; fi
  m="$(tier_model "$tier")"
  echo "TIER=$tier"
  echo "MODEL=${m}"
  echo "SUGGEST=\"claude: ${m:-<default>} ($tier tier)\""
}

CMD="${1:-}"; shift || true
case "$CMD" in
  suggest) resolve_suggest "$@" ;;
  tier)    echo "MODEL=$(tier_model "${1:-standard}")" ;;
  show)    for t in power standard lite; do echo "$t: $(tier_model "$t")"; done ;;
  *) echo "Usage: resolve-model.sh <suggest \"<task>\" | tier <power|standard|lite> | show>" >&2; exit 1 ;;
esac
