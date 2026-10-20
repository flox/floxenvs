#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists flox-agent
command_exists node
command_exists npx
command_exists gum

# Reuse the same plugin-layout checks as the minimal env.
plugin_dir="$FLOX_ENV/share/agent-plugins/agentmemory"
if [ ! -d "$plugin_dir" ]; then
  echo "Error: plugin dir missing: $plugin_dir"
  exit 1
fi
echo ">>> plugin installed at $plugin_dir"

# flox-agent must see the plugin it will hand to Claude Code. Capture
# the output with `|| true` so a non-zero exit doesn't fail the pipe
# under `pipefail`.
list_out="$(flox-agent list 2>&1 || true)"
if ! grep -q agent-plugin-agentmemory <<<"$list_out"; then
  echo "Error: flox-agent list did not show agentmemory"
  echo "$list_out" | head -40
  exit 1
fi
echo ">>> flox-agent sees the agentmemory plugin"

status="$(flox services status 2>&1)"
if ! echo "$status" | grep -q agentmemory; then
  echo "Error: agentmemory service not configured"
  echo "$status"
  exit 1
fi
echo ">>> agentmemory service configured"

echo ">>> agentmemory-demo environment is working"
