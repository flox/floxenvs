#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists claude
command_exists claude-managed
command_exists node
command_exists npx
command_exists gum

# Reuse the same plugin-layout checks as the minimal env.
plugin_dir="$FLOX_ENV/share/claude-code/plugins/agentmemory"
if [ ! -d "$plugin_dir" ]; then
  echo "Error: plugin dir missing: $plugin_dir"
  exit 1
fi
echo ">>> plugin installed at $plugin_dir"

if ! claude-managed doctor 2>&1 | grep -q agentmemory; then
  echo "Error: claude-managed doctor did not surface agentmemory"
  claude-managed doctor 2>&1 | head -40
  exit 1
fi
echo ">>> claude-managed sees the agentmemory plugin"

status="$(flox services status 2>&1)"
if ! echo "$status" | grep -q agentmemory; then
  echo "Error: agentmemory service not configured"
  echo "$status"
  exit 1
fi
echo ">>> agentmemory service configured"

echo ">>> agentmemory-demo environment is working"
