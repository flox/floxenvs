#!/usr/bin/env bash

set -eo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Error: 'node' command not found."
  exit 1
fi
if ! command -v flox-ai >/dev/null 2>&1; then
  echo "Error: 'flox-ai' command not found."
  exit 1
fi

echo ">>> node version: $(node --version)"

# The plugin ships its skill tree under
# $FLOX_ENV/share/flox/claude/remotion/. Verify the
# files flox-ai will discover are actually present —
# without them the on-activate hook would silently register
# an empty plugin.
plugin_dir="$FLOX_ENV/share/flox/claude/remotion"
if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
  echo "Error: plugin.json missing at $plugin_dir"
  exit 1
fi
if [ ! -f "$plugin_dir/skills/remotion/SKILL.md" ]; then
  echo "Error: SKILL.md missing at $plugin_dir"
  exit 1
fi
echo ">>> remotion plugin tree present"

# flox-ai should discover the fragment shipped under
# share/flox and surface its skill. Without this the
# skill would not be available to launched AI agents.
if ! flox-ai search remotion 2>&1 | grep -q remotion; then
  echo "Error: flox-ai did not discover the remotion skill"
  flox-ai doctor || true
  exit 1
fi
echo ">>> flox-ai discovered the remotion skill"

echo ">>> remotion environment is working"
