#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands ─────────────────────────────────
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

if [ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-}" != "1" ]; then
  echo "Error: CLAUDE_CODE_DISABLE_AUTO_MEMORY not set."
  exit 1
fi
echo ">>> CLAUDE_CODE_DISABLE_AUTO_MEMORY=1"

# ── Config dir exists ─────────────────────────────────
if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
  echo "Error: CLAUDE_CONFIG_DIR does not exist: $CLAUDE_CONFIG_DIR"
  exit 1
fi
echo ">>> config dir exists"

# ── Doctor check ──────────────────────────────────────
echo ">>> claude-managed doctor"
claude-managed doctor

# ── Status ────────────────────────────────────────────
echo ">>> claude-managed status"
claude-managed status

echo ">>> claude environment is working"
