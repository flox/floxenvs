#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists iloom
command_exists il
command_exists gh
command_exists git

iloom_version="$(iloom --version)"
il_version="$(il --version)"
echo ">>> iloom version: $iloom_version"
echo ">>> il version: $il_version"
echo ">>> gh version: $(gh --version | head -1)"

# `iloom` and `il` are separate wrapper scripts around the
# same underlying CLI — their --version outputs must agree.
if [ "$iloom_version" != "$il_version" ]; then
  echo "Error: 'iloom --version' and 'il --version' disagree:"
  echo "  iloom -> $iloom_version"
  echo "  il    -> $il_version"
  exit 1
fi
echo ">>> 'iloom' and 'il' report the same version"

echo ">>> iloom environment is working"
