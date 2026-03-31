#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v $1 2>&1 >/dev/null; then
    echo "Error: '$1' command could not be found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists colima
command_exists docker
command_exists docker-compose
command_exists lazydocker
command_exists oxker
command_exists ctop
command_exists dive
