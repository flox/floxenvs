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
command_exists claude
command_exists claude-managed

# ── Demo-only ──────────────────────────────────────────
command_exists gum

echo ">>> node version:    $(node --version)"
echo ">>> npm version:     $(npm --version)"
echo ">>> claude version:  $(claude --version 2>&1 | head -1)"
echo ">>> gum version:     $(gum --version)"

# ── Plugin tree present ────────────────────────────────
plugin_dir="$FLOX_ENV/share/claude-code/plugins/remotion"
if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
  echo "Error: plugin.json missing at $plugin_dir"
  exit 1
fi
if [ ! -f "$plugin_dir/skills/remotion/SKILL.md" ]; then
  echo "Error: SKILL.md missing at $plugin_dir"
  exit 1
fi
echo ">>> remotion plugin tree present"

# ── claude-managed registered the plugin ───────────────
if ! claude-managed plugins list 2>&1 | grep -q remotion; then
  echo "Error: claude-managed did not register the remotion plugin"
  claude-managed doctor || true
  exit 1
fi
echo ">>> claude-managed registered the remotion plugin"

echo ">>> remotion-demo environment is working"
