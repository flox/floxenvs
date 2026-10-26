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

# The hook hands Claude Code the service's API secret.
if [ -z "${AGENTMEMORY_SECRET:-}" ]; then
  echo "Error: AGENTMEMORY_SECRET not set by the activation hook"
  exit 1
fi
echo ">>> AGENTMEMORY_SECRET set"

# Same health check as the minimal env: the included backend must serve.
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

echo ">>> agentmemory-demo environment is working"
