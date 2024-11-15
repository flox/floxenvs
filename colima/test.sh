#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v $1 2>&1 >/dev/null; then
    echo "Error: '$1' command could not be found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

docker_is_running() {
  local elapsed=0 

  while [ 0 -lt 45 ]; do
      if docker info &> /dev/null; then
          echo ">>> Docker is running."
          return 0
      fi
      sleep 5
      elapsed=$((elapsed + 5))
  done

  echo "Error: Docker failed to start within 45 seconds."
  return 1
}

command_exists colima
command_exists docker
command_exists gum

docker_is_running
