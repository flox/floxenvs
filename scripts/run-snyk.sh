#!/usr/bin/env bash
# Scan a single item with snyk test.
# Usage: scripts/run-snyk.sh <kind> <name> <dir>
# Output: JSON array of findings on stdout.
# Gracefully no-ops when:
#   - SNYK_TOKEN is unset or empty (no findings, no error)
#   - snyk binary is not on PATH
set -euo pipefail

# shellcheck disable=SC2034  # KIND: positional argument, used for validation
KIND=${1:?kind (env|pkg) required}
# shellcheck disable=SC2034  # NAME: positional argument, used for validation
NAME=${2:?name required}
DIR=${3:?absolute item directory required}

if [[ -z "${SNYK_TOKEN:-}" ]]; then
  echo "[]"
  exit 0
fi
if ! command -v snyk >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || {
  echo "[]" # no-op: not a git repo
  exit 0
}

# snyk test reads SNYK_TOKEN from env. It exits
# non-zero on findings, which is fine — we just want the
# JSON. Use a temp file to capture stdout independent of
# exit code.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
snyk test --json "$DIR" >"$tmp" 2>/dev/null || true

if [[ ! -s $tmp ]]; then
  echo "[]"
  exit 0
fi

"${ROOT}/scripts/lib/snyk-to-findings.sh" <"$tmp"
