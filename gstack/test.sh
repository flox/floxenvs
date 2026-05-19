#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (inherited from flox/claude) ────
command_exists claude
command_exists claude-managed

echo ">>> claude version: $(claude --version)"
echo ">>> claude-managed version: $(claude-managed version)"

# ── Managed mode ──────────────────────────────────────
if [ "${CLAUDE_MANAGED:-}" != "1" ]; then
  echo "Error: CLAUDE_MANAGED not set."
  exit 1
fi
echo ">>> CLAUDE_MANAGED=1"

if [ -z "${CLAUDE_CONFIG_DIR:-}" ]; then
  echo "Error: CLAUDE_CONFIG_DIR not set."
  exit 1
fi
echo ">>> CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"

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

skill_count=$(find "$GSTACK_ROOT/skills" -maxdepth 1 -mindepth 1 \
  \( -type d -o -type l \) | wc -l | tr -d ' ')
if [ "$skill_count" -lt 40 ]; then
  echo "Error: expected at least 40 skills, found $skill_count"
  exit 1
fi
echo ">>> skills/ has $skill_count entries"

# ── Bundled runtime tools ─────────────────────────────
for tool in bun node git jq curl; do
  if [ ! -x "$GSTACK_ROOT/tools/bin/$tool" ]; then
    echo "Error: bundled tool missing: $tool"
    exit 1
  fi
done
echo ">>> bundled tools present"

# ── Plugin is discoverable through claude-managed ─────
echo ">>> claude-managed doctor"
claude-managed doctor

echo ">>> gstack environment is working"
