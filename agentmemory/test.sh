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

echo ">>> node version: $(node --version)"

# Plugin tree must land where flox-agent discovers it: the Agent
# Plugins layout under share/agent-plugins/<name>/.
plugin_dir="$FLOX_ENV/share/agent-plugins/agentmemory"
if [ ! -d "$plugin_dir" ]; then
  echo "Error: plugin dir missing: $plugin_dir"
  exit 1
fi
echo ">>> plugin installed at $plugin_dir"

for f in \
  plugin.json \
  mcp.json \
  com.anthropic.claude-code/hooks/hooks.json \
  scripts/session-start.mjs \
  skills/remember/SKILL.md \
  bin/node
do
  if [ ! -e "$plugin_dir/$f" ]; then
    echo "Error: missing $plugin_dir/$f"
    exit 1
  fi
done
echo ">>> plugin layout looks complete"

# Hook scripts must have been repointed at the bundled node
# (not /usr/bin/env node) so they don't depend on the consumer env's
# PATH having node on it. The build bakes an absolute /nix/store path
# into the shebang, so just confirm /usr/bin/env is gone.
shebang="$(head -1 "$plugin_dir/scripts/session-start.mjs")"
case "$shebang" in
  *'/usr/bin/env'*)
    echo "Error: session-start.mjs still uses /usr/bin/env: $shebang"
    exit 1
    ;;
esac
echo ">>> hook script shebang repointed off /usr/bin/env"

if [ ! -x "$plugin_dir/bin/node" ]; then
  echo "Error: bundled node missing/not executable: $plugin_dir/bin/node"
  exit 1
fi
echo ">>> bundled node executable at $plugin_dir/bin/node"

# hooks.json must invoke the plugin's own bundled node, not whatever
# node happens to be on PATH.
if ! grep -qF '/share/agent-plugins/agentmemory/bin/node' \
    "$plugin_dir/com.anthropic.claude-code/hooks/hooks.json"; then
  echo "Error: hooks.json not wired to bundled node"
  exit 1
fi
echo ">>> hooks.json wired to bundled node"

# Same for the MCP server: mcp.json runs the bundled node, which
# `flox-agent launch` rewrites to ${CLAUDE_PLUGIN_ROOT}/bin/node.
if ! grep -qF '"./bin/node"' "$plugin_dir/mcp.json"; then
  echo "Error: mcp.json not wired to bundled node"
  exit 1
fi
echo ">>> mcp.json wired to bundled node"

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

# The hook hands Claude Code the service's API secret.
if [ -z "${AGENTMEMORY_SECRET:-}" ]; then
  echo "Error: AGENTMEMORY_SECRET not set by the activation hook"
  exit 1
fi
echo ">>> AGENTMEMORY_SECRET set"

# The backend must actually serve. /agentmemory/health sits behind the
# server's bearer secret. The first start also downloads the npm
# package, hence the long wait.
health_url="$AGENTMEMORY_URL/agentmemory/health"
echo -n "Waiting for $health_url .."
MAX=180
while [[ "$MAX" != "0" ]]; do
  if health="$(curl -fsS -H "Authorization: Bearer $AGENTMEMORY_SECRET" "$health_url" 2>/dev/null)"; then
    echo ""
    break
  fi
  echo -n "."
  sleep 1
  MAX=$((MAX-1))
done
if [[ "$MAX" == "0" ]]; then
  echo ""
  echo "Error: agentmemory backend did not become healthy."
  flox services status || true
  flox services logs agentmemory 2>&1 | tail -80 || true
  exit 1
fi
if ! node -e '
  const h = JSON.parse(require("fs").readFileSync(0, "utf8"));
  process.exit(h.service === "agentmemory" ? 0 : 1);
' <<<"$health"; then
  echo "Error: unexpected health response: $health"
  exit 1
fi
echo ">>> $health_url: $(head -c 200 <<<"$health")"

# A healthy answer on the port could come from some other agentmemory
# (a leftover engine, a parallel test), so the service itself must be up.
status="$(flox services status 2>&1)"
if ! grep -Eq '^agentmemory[[:space:]]+Running' <<<"$status"; then
  echo "Error: agentmemory service is not running"
  echo "$status"
  exit 1
fi
echo ">>> agentmemory service running"

# The CLI's runtime state (engine state, pidfiles, secret) must live in
# the env cache, not the user's ~/.agentmemory.
state="$AGENTMEMORY_CACHE/home/.agentmemory/engine-state.json"
if [ ! -f "$state" ]; then
  echo "Error: CLI state not under the env cache: $state missing"
  exit 1
fi
echo ">>> CLI state under $AGENTMEMORY_CACHE/home"

echo ">>> agentmemory environment is working"
