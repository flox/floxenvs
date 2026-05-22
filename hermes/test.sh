#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists hermes
command_exists rg
command_exists ffmpeg
command_exists git
command_exists node

echo ">>> hermes version: $(hermes --version)"

if [ -z "${HERMES_HOME:-}" ] || [ ! -d "$HERMES_HOME" ]; then
  echo "Error: HERMES_HOME missing: ${HERMES_HOME:-<unset>}"
  exit 1
fi
echo ">>> HERMES_HOME=$HERMES_HOME"

if [ ! -f "$HERMES_HOME/config.yaml" ]; then
  echo "Error: $HERMES_HOME/config.yaml not seeded"
  exit 1
fi
grep -q 'allow_lazy_installs: false' \
  "$HERMES_HOME/config.yaml" || {
  echo "Error: allow_lazy_installs not disabled"
  exit 1
}
echo ">>> lazy-install suppression seeded"

echo ">>> hermes environment is working"
