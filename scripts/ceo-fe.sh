#!/usr/bin/env bash
# /ceo-fe — run from any terminal with the configured AI
# Usage: bash scripts/ceo-fe.sh "description"
# Config: set runner.cli and runner.model in project.config.md
bash "$(dirname "$0")/run-command.sh" ceo-fe "$@"
