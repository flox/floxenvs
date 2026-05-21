#!/usr/bin/env bash
set -eo pipefail

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' command not found."
  exit 1
fi
echo ">>> gum present"

if ! command -v finceptterminal >/dev/null 2>&1; then
  echo "Error: 'finceptterminal' command not found (include broken?)."
  exit 1
fi
echo ">>> finceptterminal present"

echo ">>> finceptterminal-demo environment is working"
