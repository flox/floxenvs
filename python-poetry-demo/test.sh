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

# Verify poetry env exists
POETRY_VENV="$(poetry env info --path 2>/dev/null || echo "")"
if [ -z "$POETRY_VENV" ]; then
  echo "Error: Poetry virtual environment not created"
  exit 1
fi
echo ">>> Poetry venv: $POETRY_VENV"

# Verify sample package
if [ -f pyproject.toml ]; then
  python3 -c "import cowsay; cowsay.cow('Moo from flox!')"
  echo ">>> Package import ... OK"
fi

echo ">>> python-poetry-demo environment is working"
