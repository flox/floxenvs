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
command_exists flox-ai
command_exists node
command_exists npx

echo ">>> node version: $(node --version)"
echo ">>> claude version: $(claude --version 2>&1 | head -1)"

# Plugin tree must land where flox-ai discovers it.
plugin_dir="$FLOX_ENV/share/claude-code/plugins/agentmemory"
if [ ! -d "$plugin_dir" ]; then
  echo "Error: plugin dir missing: $plugin_dir"
  exit 1
fi
echo ">>> plugin installed at $plugin_dir"

for f in \
  .claude-plugin/plugin.json \
  .mcp.json \
  hooks/hooks.json \
  scripts/session-start.mjs \
  skills/remember/SKILL.md \
  bin/node \
  bin/npx
do
  if [ ! -e "$plugin_dir/$f" ]; then
    echo "Error: missing $plugin_dir/$f"
    exit 1
  fi
done
echo ">>> plugin layout looks complete"

# Hook scripts must have been repointed at the bundled node
# (not /usr/bin/env node) so they don't depend on the
# consumer env's PATH having node on it. The substituted path is
# the build-time $PLUGIN_DIR (a /nix/store path) rather than the
# env's runtime mount of it, so just confirm /usr/bin/env is gone
# and the shebang resolves to an executable.
shebang="$(head -1 "$plugin_dir/scripts/session-start.mjs")"
case "$shebang" in
  *'/usr/bin/env'*)
    echo "Error: session-start.mjs still uses /usr/bin/env: $shebang"
    exit 1
    ;;
esac
shebang_bin="${shebang#\#!}"
if [ ! -x "$shebang_bin" ]; then
  echo "Error: session-start.mjs shebang target not executable: $shebang_bin"
  exit 1
fi
echo ">>> hook script shebang resolves to $shebang_bin"

# hooks.json must invoke the bundled node via the
# ${CLAUDE_PLUGIN_ROOT}-anchored path so Claude Code can
# expand it at load time without depending on PATH.
if ! grep -qF '${CLAUDE_PLUGIN_ROOT}/bin/node' "$plugin_dir/hooks/hooks.json"; then
  echo "Error: hooks.json not rewritten to bundled node"
  exit 1
fi
echo ">>> hooks.json wired to bundled node"

# Same for .mcp.json's npx invocation.
if ! grep -qF '${CLAUDE_PLUGIN_ROOT}/bin/npx' "$plugin_dir/.mcp.json"; then
  echo "Error: .mcp.json not rewritten to bundled npx"
  exit 1
fi
echo ">>> .mcp.json wired to bundled npx"

# Vars set up correctly.
if [ "${AGENTMEMORY_URL:-}" != "http://localhost:3111" ]; then
  echo "Error: AGENTMEMORY_URL not at default: ${AGENTMEMORY_URL:-<unset>}"
  exit 1
fi
echo ">>> AGENTMEMORY_URL=$AGENTMEMORY_URL"

if [ -z "${AGENTMEMORY_CACHE:-}" ] || [ ! -d "$AGENTMEMORY_CACHE" ]; then
  echo "Error: AGENTMEMORY_CACHE missing: ${AGENTMEMORY_CACHE:-<unset>}"
  exit 1
fi
echo ">>> AGENTMEMORY_CACHE=$AGENTMEMORY_CACHE"

# flox-ai must report the plugin as discovered.
if ! flox-ai doctor 2>&1 | grep -q agentmemory; then
  echo "Error: flox-ai doctor did not surface agentmemory"
  flox-ai doctor 2>&1 | head -40
  exit 1
fi
echo ">>> flox-ai sees the agentmemory plugin"

# Service must be defined.
status="$(flox services status 2>&1)"
if ! echo "$status" | grep -q agentmemory; then
  echo "Error: agentmemory service not configured"
  echo "$status"
  exit 1
fi
echo ">>> agentmemory service configured"

echo ">>> agentmemory environment is working"
