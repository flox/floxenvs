#!/usr/bin/env bash

set -eo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Error: 'node' command not found."
  exit 1
fi
if ! command -v flox-agent >/dev/null 2>&1; then
  echo "Error: 'flox-agent' command not found."
  exit 1
fi

echo ">>> node version: $(node --version)"

# The plugin ships its skill tree under
# $FLOX_ENV/share/agent-plugins/remotion-dev-skills/. Verify
# the files flox-agent will hand to Claude Code are actually
# present — without them launch would load an empty plugin.
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

# flox-agent should see the plugin under share/agent-plugins.
# Without this the skills would not be available to launched
# AI agents.
if ! flox-agent list 2>&1 | grep -q agent-plugin-remotion-dev-skills; then
  echo "Error: flox-agent did not discover the remotion plugin"
  flox-agent doctor || true
  exit 1
fi
echo ">>> flox-agent discovered the remotion plugin"

echo ">>> remotion environment is working"
