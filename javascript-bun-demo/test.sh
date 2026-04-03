#!/usr/bin/env bash

set -eo pipefail

if ! command -v bun >/dev/null 2>&1; then
  echo "Error: 'bun' command not found."
  exit 1
fi

echo ">>> bun version: $(bun --version)"

# Verify figlet installed from package.json
if [ -f package.json ]; then
  echo ">>> Verifying packages..."
  bun --eval "import('figlet')"
  echo ">>> Package import ... OK"
fi

# Run sample script
if [ -f index.ts ]; then
  bun index.ts
  echo ">>> index.ts ... OK"
fi

echo ">>> javascript-bun-demo environment is working"
