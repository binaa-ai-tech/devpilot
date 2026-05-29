#!/usr/bin/env bash
# /ceo-db — run from any terminal with the configured AI
# Usage: bash scripts/ceo-db.sh "description"
# Config: set runner.cli and runner.model in project.config.md
bash "$(dirname "$0")/run-command.sh" ceo-db "$@"
