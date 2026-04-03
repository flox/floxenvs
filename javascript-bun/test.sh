#!/usr/bin/env bash

set -eo pipefail

if ! command -v bun >/dev/null 2>&1; then
  echo "Error: 'bun' command not found."
  exit 1
fi

echo ">>> bun version: $(bun --version)"

echo ">>> javascript-bun environment is working"
