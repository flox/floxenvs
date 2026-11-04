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
command_exists flox-agent
command_exists gum

echo ">>> claude version: $(claude --version)"
echo ">>> gum version: $(gum --version)"

# The demo installs one agent plugin; `claude` must hand it to
# Claude Code through flox-agent.
plugins="$(claude plugin list)"
echo "$plugins"
if ! grep -q "claude-md-management" <<<"$plugins"; then
  echo "Error: claude-md-management plugin not loaded."
  exit 1
fi
echo ">>> claude-md-management plugin loaded"

echo ">>> claude-demo environment is working"
