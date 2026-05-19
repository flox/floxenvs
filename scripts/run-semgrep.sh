#!/usr/bin/env bash
# Scan a single item with the Flox semgrep ruleset.
# Usage: scripts/run-semgrep.sh <kind> <name> <dir>
# Output: JSON array of findings on stdout.
# Gracefully no-ops (empty array) when semgrep is not on
# PATH so this script is safe to add to run-audit.sh
# before semgrep is installed in CI.
set -euo pipefail

# shellcheck disable=SC2034  # KIND: positional argument, used for validation
KIND=${1:?kind (env|pkg) required}
# shellcheck disable=SC2034  # NAME: positional argument, used for validation
NAME=${2:?name required}
DIR=${3:?absolute item directory required}

ROOT=$(git -C "$DIR" rev-parse --show-toplevel)
RULES="${ROOT}/.semgrep/flox.yaml"

if ! command -v semgrep >/dev/null 2>&1; then
  echo "[]" # no-op: semgrep absent
  exit 0
fi
if [[ ! -f $RULES ]]; then
  echo "[]" # no rules file yet
  exit 0
fi

semgrep --quiet --config "$RULES" --json "$DIR" 2>/dev/null \
  | "${ROOT}/scripts/lib/semgrep-to-findings.sh"
