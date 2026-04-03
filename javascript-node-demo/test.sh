#!/usr/bin/env bash

set -eo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Error: 'node' command not found."
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: 'npm' command not found."
  exit 1
fi

echo ">>> node version: $(node --version)"
echo ">>> npm version: $(npm --version)"

# Verify figlet installed from package.json
if [ -f package.json ]; then
  echo ">>> Verifying packages..."
  node --eval "require('figlet')"
  echo ">>> Package import ... OK"
fi

# Run sample script
if [ -f index.js ]; then
  node index.js
  echo ">>> index.js ... OK"
fi

echo ">>> javascript-node-demo environment is working"
