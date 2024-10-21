#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v $1 2>&1 >/dev/null; then
    echo "Error: '$1' command could not be found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists fzf
command_exists zoxide
