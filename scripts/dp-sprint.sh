#!/usr/bin/env bash
# /dp-sprint — run from any terminal with the configured AI
# Usage: bash scripts/dp-sprint.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-sprint "$@"
