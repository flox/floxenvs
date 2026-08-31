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
command_exists mergekit-yaml
command_exists mergekit-moe
command_exists mergekit-extract-lora

# Exercise transitive imports (torch, transformers, pydantic, ...)
# via the help screen. Failure here = a dep failed to load.
mergekit-yaml --help > /dev/null
echo ">>> mergekit-yaml --help loaded all deps"

mergekit-moe --help > /dev/null
echo ">>> mergekit-moe --help loaded all deps"

# Confirm merge-config parsing works without any model download:
# an invalid config must fail during validation, not import.
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cat > "$WORKDIR/invalid.yml" <<'YAML'
merge_method: does-not-exist
YAML
if mergekit-yaml "$WORKDIR/invalid.yml" "$WORKDIR/out" \
     > /dev/null 2>&1; then
  echo "Error: invalid merge config unexpectedly succeeded."
  exit 1
fi
echo ">>> mergekit-yaml rejects invalid merge config"

echo ">>> mergekit environment is working"
