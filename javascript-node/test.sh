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

echo ">>> javascript-node environment is working"
