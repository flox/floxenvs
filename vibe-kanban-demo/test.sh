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
command_exists gum

echo ">>> gum version: $(gum --version)"

if [ -z "${XDG_DATA_HOME:-}" ] || [ ! -d "$XDG_DATA_HOME" ]; then
  echo "Error: XDG_DATA_HOME missing: ${XDG_DATA_HOME:-<unset>}"
  exit 1
fi
echo ">>> XDG_DATA_HOME=$XDG_DATA_HOME"

echo ">>> vibe-kanban-demo environment is working"
