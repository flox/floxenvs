#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists wt
command_exists git-wt
command_exists git
command_exists gum

echo ">>> wt version: $(wt --version)"
echo ">>> gum version: $(gum --version)"

echo ">>> worktrunk-demo environment is working"
