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

echo ">>> iloom version: $(iloom --version)"
echo ">>> il version: $(il --version)"
echo ">>> gh version: $(gh --version | head -1)"

# iloom and il are the same binary — sanity check that the
# alias resolves to the same content.
iloom_path=$(command -v iloom)
il_path=$(command -v il)
if [ "$(readlink -f "$iloom_path")" != "$(readlink -f "$il_path")" ]; then
  echo "Error: 'iloom' and 'il' resolve to different binaries."
  echo "  iloom -> $iloom_path"
  echo "  il    -> $il_path"
  exit 1
fi
echo ">>> 'iloom' and 'il' resolve to the same binary"

echo ">>> iloom environment is working"
