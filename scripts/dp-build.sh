#!/usr/bin/env bash
# /dp-build — run from any terminal with the configured AI
# Usage: bash scripts/dp-build.sh "<args>"
bash "$(dirname "$0")/run-command.sh" dp-build "$@"
