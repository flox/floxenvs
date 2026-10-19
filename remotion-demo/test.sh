#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (inherited from ../remotion) ─────
command_exists node
command_exists npx
command_exists flox-agent

# ── Demo-only ──────────────────────────────────────────
command_exists gum

echo ">>> node version:    $(node --version)"
echo ">>> npm version:     $(npm --version)"
echo ">>> gum version:     $(gum --version)"

# ── Plugin tree present ────────────────────────────────
plugin_dir="$FLOX_ENV/share/agent-plugins/remotion-dev-skills"
if [ ! -f "$plugin_dir/plugin.json" ]; then
  echo "Error: plugin.json missing at $plugin_dir"
  exit 1
fi
if [ ! -f "$plugin_dir/skills/remotion-best-practices/SKILL.md" ]; then
  echo "Error: SKILL.md missing at $plugin_dir"
  exit 1
fi
echo ">>> remotion plugin tree present"

# ── flox-agent discovered the plugin ───────────
if ! flox-agent list 2>&1 | grep -q agent-plugin-remotion-dev-skills; then
  echo "Error: flox-agent did not discover the remotion plugin"
  flox-agent doctor || true
  exit 1
fi
echo ">>> flox-agent discovered the remotion plugin"

echo ">>> remotion-demo environment is working"
