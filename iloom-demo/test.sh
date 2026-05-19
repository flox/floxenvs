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
command_exists gum

echo ">>> iloom version: $(iloom --version)"
echo ">>> gum version: $(gum --version)"

echo ">>> iloom-demo environment is working"
