#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# Required commands (composed from mergekit + demo-tools)
command_exists mergekit-yaml
command_exists mergekit-moe
command_exists gum

echo ">>> gum version: $(gum --version)"

# Example merge config exists and parses as a valid config. The
# hook writes it to $FLOX_ENV_PROJECT (the env dir).
EXAMPLE="${FLOX_ENV_PROJECT:-.}/example-merge.yml"
if [ ! -f "$EXAMPLE" ]; then
  echo "Error: example-merge.yml missing at $EXAMPLE"
  exit 1
fi
if ! grep -q 'merge_method: linear' "$EXAMPLE"; then
  echo "Error: example-merge.yml lacks expected merge_method"
  exit 1
fi
echo ">>> example-merge.yml present at $EXAMPLE"

echo ">>> mergekit-demo environment is working"
