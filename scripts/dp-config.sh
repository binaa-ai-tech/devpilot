#!/usr/bin/env bash
# /dp-config — run from any terminal with the configured AI
# Usage: bash scripts/dp-config.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-config "$@"
