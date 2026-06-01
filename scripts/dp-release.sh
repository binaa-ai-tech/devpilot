#!/usr/bin/env bash
# /dp-release — run from any terminal with the configured AI
# Usage: bash scripts/dp-release.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-release "$@"
