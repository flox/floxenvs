#!/usr/bin/env bash
set -eo pipefail

for c in symphony codex git bash; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "Error: '$c' command not found."
    exit 1
  fi
  echo ">>> $c ... OK"
done

echo ">>> symphony version: $(symphony version 2>&1 | head -1)"
echo ">>> codex version:    $(codex --version 2>&1 | head -1)"

echo ">>> symphony environment is working"
