#!/usr/bin/env bash
# /dp-status — run from any terminal with the configured AI
# Usage: bash scripts/dp-status.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-status "$@"
