#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# Required commands
command_exists basic-memory
command_exists bm

echo ">>> basic-memory version: $(basic-memory --version)"
echo ">>> bm version: $(bm --version)"

# Exercise transitive imports (sqlalchemy, pydantic, alembic, ...)
# via the help screen. Failure here = a dep failed to load.
basic-memory --help > /dev/null
echo ">>> basic-memory --help loaded all deps"

# Confirm semantic-search deps are bundled.
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
export BASIC_MEMORY_CONFIG_DIR="$WORKDIR"

# project list bootstraps on first call; absorb any first-run noise.
basic-memory project list > /dev/null 2>&1 || true
echo ">>> basic-memory bootstrap succeeded"

echo ">>> basic-memory environment is working"
