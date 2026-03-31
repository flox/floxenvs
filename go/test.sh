#!/usr/bin/env bash

set -eo pipefail

if ! command -v go >/dev/null 2>&1; then
  echo "Error: 'go' command not found."
  exit 1
fi

echo ">>> go version"
go version

echo ">>> Go environment is working"
