#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists flox-ai
command_exists node
command_exists npx
command_exists gum

# Reuse the same plugin-layout checks as the minimal env.
plugin_dir="$FLOX_ENV/share/flox/claude/agentmemory"
if [ ! -d "$plugin_dir" ]; then
  echo "Error: plugin dir missing: $plugin_dir"
  exit 1
fi
echo ">>> plugin installed at $plugin_dir"

# flox-ai must discover the plugin's skills. `search` lists fragments
# matching a query; the bundled skills surface under the
# skills-agentmemory id, so confirm agentmemory is found. Capture the
# output with `|| true` so a non-zero exit doesn't fail the pipe under
# `pipefail`.
search_out="$(flox-ai search agentmemory 2>&1 || true)"
if ! grep -q agentmemory <<<"$search_out"; then
  echo "Error: flox-ai search did not surface agentmemory"
  echo "$search_out" | head -40
  exit 1
fi
echo ">>> flox-ai sees the agentmemory plugin"

status="$(flox services status 2>&1)"
if ! echo "$status" | grep -q agentmemory; then
  echo "Error: agentmemory service not configured"
  echo "$status"
  exit 1
fi
echo ">>> agentmemory service configured"

echo ">>> agentmemory-demo environment is working"
