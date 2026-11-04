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

# `claude` must be the activation's wrapper, not claude-code
# itself, or sessions start without the environment's plugins.
wrapper="$FLOX_ENV_CACHE/claude/bin/claude"
if [ "$(command -v claude)" != "$wrapper" ]; then
  echo "Error: 'claude' resolves to $(command -v claude), not $wrapper"
  exit 1
fi
echo ">>> claude resolves to the flox-agent wrapper"

# --version goes through `flox-agent launch claude`, so a
# wrapper that finds itself instead of claude-code loops here
# rather than printing a version.
echo ">>> claude version: $(claude --version)"
echo ">>> flox-agent version: $(flox-agent version)"

echo ">>> claude environment is working"
