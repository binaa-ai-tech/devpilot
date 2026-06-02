#!/usr/bin/env bash
# /dp-plan — run from any terminal with the configured AI
# Usage: bash scripts/dp-plan.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-plan "$@"
