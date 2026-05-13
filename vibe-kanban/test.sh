#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists vibe-kanban
command_exists vibe-kanban-mcp
command_exists vibe-kanban-review

# vibe-kanban has no --version flag — running it starts the
# server. The command-exists checks above are the smoke test.

if [ -z "${VIBE_KANBAN_CACHE:-}" ]; then
  echo "Error: VIBE_KANBAN_CACHE not set."
  exit 1
fi
echo ">>> VIBE_KANBAN_CACHE=$VIBE_KANBAN_CACHE"

if [ -z "${XDG_DATA_HOME:-}" ] || [ ! -d "$XDG_DATA_HOME" ]; then
  echo "Error: XDG_DATA_HOME missing: ${XDG_DATA_HOME:-<unset>}"
  exit 1
fi
echo ">>> XDG_DATA_HOME=$XDG_DATA_HOME"

if [ "${BACKEND_PORT:-}" != "13456" ]; then
  echo "Error: BACKEND_PORT not 13456: ${BACKEND_PORT:-<unset>}"
  exit 1
fi
echo ">>> BACKEND_PORT=$BACKEND_PORT"

echo ">>> vibe-kanban environment is working"
