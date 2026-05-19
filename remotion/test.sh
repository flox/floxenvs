#!/usr/bin/env bash

set -eo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Error: 'node' command not found."
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' command not found."
  exit 1
fi
if ! command -v claude-managed >/dev/null 2>&1; then
  echo "Error: 'claude-managed' command not found."
  exit 1
fi

echo ">>> node version: $(node --version)"
echo ">>> claude version: $(claude --version 2>&1 | head -1)"

# The plugin ships its skill tree under
# $FLOX_ENV/share/claude-code/plugins/remotion/. Verify the
# files claude-managed will discover are actually present —
# without them the on-activate hook would silently register
# an empty plugin.
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

# claude-managed setup-hook ran in on-activate and should
# have symlinked the plugin under .claude-managed/. Without
# this Claude Code lists the plugin but won't load it.
if ! claude-managed plugins list 2>&1 | grep -q remotion; then
  echo "Error: claude-managed did not register the remotion plugin"
  claude-managed doctor || true
  exit 1
fi
echo ">>> claude-managed registered the remotion plugin"

echo ">>> remotion environment is working"
