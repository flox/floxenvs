#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v pip >/dev/null 2>&1; then
  echo "Error: 'pip' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> pip version: $(pip --version)"

# Verify venv is active
VENV_PREFIX="$(python3 -c 'import sys; print(sys.prefix)')"
if [[ "$VENV_PREFIX" != *"python-pip"* ]]; then
  echo "Error: Virtual environment not active (prefix: $VENV_PREFIX)"
  exit 1
fi
echo ">>> Virtual environment active: $VENV_PREFIX"

echo ">>> python-pip environment is working"
