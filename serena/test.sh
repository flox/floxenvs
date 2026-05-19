#!/usr/bin/env bash

set -eo pipefail

for cmd in serena serena-hooks node; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

# Wiring check — don't start the MCP server in the CI sandbox.
serena --help >/dev/null
echo ">>> serena --help ... OK"

serena start-mcp-server --help >/dev/null
echo ">>> serena start-mcp-server --help ... OK"

# Confirm the service is defined in the locked manifest.
if ! grep -q '"serena-mcp"' .flox/env/manifest.lock; then
  echo "Error: serena-mcp service not in manifest.lock"
  exit 1
fi
echo ">>> serena-mcp service defined"

echo ">>> serena environment is working"
