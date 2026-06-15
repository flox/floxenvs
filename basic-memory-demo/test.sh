#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# Required commands (composed from basic-memory + claude + demo-tools)
command_exists basic-memory
command_exists bm
command_exists claude
command_exists flox-ai
command_exists gum

echo ">>> basic-memory version: $(basic-memory --version)"
echo ">>> claude version: $(claude --version)"
echo ">>> flox-ai version: $(flox-ai version)"
echo ">>> gum version: $(gum --version)"

# .mcp.json wiring exists and references basic-memory. The hook
# writes it to $FLOX_ENV_PROJECT (the env dir). Plain grep avoids
# pulling jq into the env just for the check.
MCP_JSON="${FLOX_ENV_PROJECT:-.}/.mcp.json"
if [ ! -f "$MCP_JSON" ]; then
  echo "Error: .mcp.json missing at $MCP_JSON"
  exit 1
fi
if ! grep -q '"command": "basic-memory"' "$MCP_JSON"; then
  echo "Error: .mcp.json does not wire basic-memory"
  exit 1
fi
echo ">>> .mcp.json wiring present at $MCP_JSON"

echo ">>> basic-memory-demo environment is working"
