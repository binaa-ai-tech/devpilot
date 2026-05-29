#!/usr/bin/env bash
# /ceo-plan — run from any terminal with the configured AI
# Usage: bash scripts/ceo-plan.sh "description"
# Config: set runner.cli and runner.model in project.config.md
bash "$(dirname "$0")/run-command.sh" ceo-plan "$@"
