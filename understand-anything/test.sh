#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Inherited from flox/claude ────────────────────────
command_exists claude
command_exists claude-managed
echo ">>> claude version: $(claude --version)"
echo ">>> claude-managed version: $(claude-managed version)"

# ── Runtime deps the plugin's skills shell out to ─────
command_exists node
command_exists pnpm
command_exists python3
command_exists git
echo ">>> node version: $(node --version)"
echo ">>> pnpm version: $(pnpm --version)"
echo ">>> python3 version: $(python3 --version)"
echo ">>> git version: $(git --version)"

# ── Plugin checkout landed in the cache ───────────────
ua_repo="$FLOX_ENV_CACHE/understand-anything/repo"
ua_plugin="$ua_repo/understand-anything-plugin"
if [ ! -d "$ua_plugin" ]; then
  echo "Error: understand-anything plugin dir missing at $ua_plugin"
  exit 1
fi
echo ">>> plugin checkout at $ua_plugin"

# ── Plugin manifest Claude Code reads on discovery ────
plugin_json="$ua_plugin/.claude-plugin/plugin.json"
if [ ! -f "$plugin_json" ]; then
  echo "Error: .claude-plugin/plugin.json missing"
  exit 1
fi
echo ">>> .claude-plugin/plugin.json present"

# ── Trust marker written by the activation hook ───────
installed="$ua_plugin/installed_plugins.json"
if [ ! -f "$installed" ]; then
  echo "Error: installed_plugins.json not generated"
  exit 1
fi
grep -q '"understand-anything@flox"' "$installed" || {
  echo "Error: installed_plugins.json missing flox entry"
  cat "$installed"
  exit 1
}
echo ">>> installed_plugins.json registers understand-anything@flox"

# ── Pinned version matches UA_VERSION ─────────────────
checked_out="$(git -C "$ua_repo" describe --tags \
  --exact-match 2>/dev/null || echo none)"
if [ "$checked_out" != "$UA_VERSION" ]; then
  echo "Error: checkout is at '$checked_out', expected '$UA_VERSION'"
  exit 1
fi
echo ">>> checkout pinned to $UA_VERSION"

# ── claude-managed sees the plugin ────────────────────
if ! claude-managed plugins list 2>&1 \
     | grep -q "understand-anything"; then
  echo "Error: claude-managed plugins list does not show understand-anything"
  claude-managed plugins list
  exit 1
fi
echo ">>> claude-managed plugins list shows understand-anything"

echo ">>> understand-anything environment is working"
