#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists codeburn

echo ">>> codeburn version: $(codeburn --version)"

# `codeburn status --format json` produces a compact JSON
# summary and exits — safe to run non-interactively even
# when there is no session data on disk.
echo ">>> codeburn status --format json"
codeburn status --format json | head -20

echo ">>> codeburn environment is working"
