#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (inherited from flox/claude + demo) ─
command_exists claude
command_exists claude-managed
command_exists gum

echo ">>> claude version: $(claude --version)"
echo ">>> claude-managed version: $(claude-managed version)"
echo ">>> gum version: $(gum --version)"

# ── Managed mode ──────────────────────────────────────
if [ "${CLAUDE_MANAGED:-}" != "1" ]; then
  echo "Error: CLAUDE_MANAGED not set."
  exit 1
fi
echo ">>> CLAUDE_MANAGED=1"

# ── gstack plugin is installed ────────────────────────
GSTACK_ROOT="$FLOX_ENV/share/claude-code/plugins/gstack"
if [ ! -d "$GSTACK_ROOT" ]; then
  echo "Error: gstack plugin dir missing: $GSTACK_ROOT"
  exit 1
fi
echo ">>> gstack plugin root: $GSTACK_ROOT"

if [ ! -f "$GSTACK_ROOT/.claude-plugin/plugin.json" ]; then
  echo "Error: plugin.json missing"
  exit 1
fi
echo ">>> plugin.json present"

# ── Doctor check ──────────────────────────────────────
echo ">>> claude-managed doctor"
claude-managed doctor

echo ">>> gstack-demo environment is working"
