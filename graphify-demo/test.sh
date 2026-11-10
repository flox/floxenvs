#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v flox-agent >/dev/null 2>&1; then
  echo "Error: 'flox-agent' command not found."
  exit 1
fi
if ! command -v graphify >/dev/null 2>&1; then
  echo "Error: 'graphify' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> flox-agent version: $(flox-agent --version 2>&1 | head -1)"
echo ">>> graphify available: $(command -v graphify)"

# Verify graphify is a working CLI (no Claude session required).
graphify --help >/dev/null

# Verify the plugin ships the skill, the spec it loads, and
# the name its slash command is namespaced by.
plugin_dir="$FLOX_ENV/share/agent-plugins/graphify-labs-graphify"
for f in plugin.json skills/graphify/SKILL.md \
    skills/graphify/references/extraction-spec.md; do
  if [ ! -f "$plugin_dir/$f" ]; then
    echo "Error: $plugin_dir/$f is missing"
    exit 1
  fi
done
if ! grep -q '"name": "graphify-labs-graphify"' "$plugin_dir/plugin.json"; then
  echo "Error: $plugin_dir/plugin.json is not named graphify-labs-graphify"
  exit 1
fi
echo ">>> graphify plugin tree present"

# Verify flox-agent loaded the plugin and its skill. The
# package name is only on a loaded plugin's row, not on a
# rejected one's.
list_out="$(flox-agent list --long 2>&1 || true)"
if ! grep -q 'agent-plugin-graphify-labs-graphify' <<<"$list_out" \
    || ! grep -qE '^ +skills +graphify$' <<<"$list_out"; then
  echo "Error: flox-agent did not load the graphify plugin."
  echo "$list_out"
  flox-agent doctor || true
  exit 1
fi
echo ">>> flox-agent loaded the graphify plugin"

echo ">>> graphify-demo environment is working"
