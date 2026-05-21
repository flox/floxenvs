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
command_exists gum

echo ">>> hermes version: $(hermes --version)"
echo ">>> gum version: $(gum --version)"

echo ">>> hermes-demo environment is working"
