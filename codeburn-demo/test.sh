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
command_exists gum

echo ">>> codeburn version: $(codeburn --version)"
echo ">>> gum version: $(gum --version)"

# `codeburn status --format json` is the safest
# non-interactive smoke test.
echo ">>> codeburn status --format json"
codeburn status --format json | head -20

echo ">>> codeburn-demo environment is working"
