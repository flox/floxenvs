#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' command not found."
  exit 1
fi
if ! command -v graphify >/dev/null 2>&1; then
  echo "Error: 'graphify' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> claude version: $(claude --version 2>&1 | head -1)"
echo ">>> graphify available: $(command -v graphify)"

echo ">>> graphify environment is working"
