#!/usr/bin/env bash

set -eo pipefail

if ! command -v podman >/dev/null 2>&1; then
  echo "Error: 'podman' command not found."
  exit 1
fi
if ! command -v podman-compose >/dev/null 2>&1; then
  echo "Error: 'podman-compose' command not found."
  exit 1
fi

echo ">>> podman version: $(podman --version)"
echo ">>> podman-compose version: $(podman-compose --version 2>&1 | head -1)"

echo ">>> podman environment is working"
