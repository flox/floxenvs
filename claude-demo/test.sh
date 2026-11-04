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
if ! grep -q "flox@" <<<"$plugins"; then
  echo "Error: flox plugin not loaded."
  exit 1
fi
echo ">>> flox plugin loaded"

echo ">>> claude-demo environment is working"
