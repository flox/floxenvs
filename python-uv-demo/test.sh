#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "Error: 'uv' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> uv version: $(uv --version)"

# Verify venv is active
VENV_PREFIX="$(python3 -c 'import sys; print(sys.prefix)')"
if [[ "$VENV_PREFIX" != *"python-uv"* ]]; then
  echo "Error: Virtual environment not active (prefix: $VENV_PREFIX)"
  exit 1
fi
echo ">>> Virtual environment active: $VENV_PREFIX"

# Run sample script if present
if [ -f hello.py ]; then
  python3 hello.py
  echo ">>> hello.py ... OK"
fi

echo ">>> python-uv-demo environment is working"
