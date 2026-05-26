#!/usr/bin/env bash
# /ceo-int — run from any terminal with the configured AI
# Usage: bash scripts/ceo-int.sh "description"
# Config: set runner.cli and runner.model in project.config.md
bash "$(dirname "$0")/run-command.sh" ceo-int "$@"
