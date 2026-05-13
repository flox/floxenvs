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

# Verify the optional extras pulled in by [mcp,watch]
# landed in the venv — the services below need them.
python3 -c "import mcp, watchdog" \
  || { echo "Error: mcp/watchdog missing from venv"; exit 1; }
echo ">>> mcp + watchdog available"

# Confirm both services are defined.
status="$(flox services status 2>&1)"
if ! echo "$status" | grep -q graphify-watch; then
  echo "Error: graphify-watch service not configured"
  echo "$status"
  exit 1
fi
if ! echo "$status" | grep -q graphify-mcp; then
  echo "Error: graphify-mcp service not configured"
  echo "$status"
  exit 1
fi
echo ">>> graphify-watch and graphify-mcp services configured"

echo ">>> graphify environment is working"
