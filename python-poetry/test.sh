#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v poetry >/dev/null 2>&1; then
  echo "Error: 'poetry' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> poetry version: $(poetry --version)"

echo ">>> python-poetry environment is working"
