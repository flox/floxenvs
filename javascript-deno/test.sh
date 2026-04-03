#!/usr/bin/env bash

set -eo pipefail

if ! command -v deno >/dev/null 2>&1; then
  echo "Error: 'deno' command not found."
  exit 1
fi

echo ">>> deno version: $(deno --version | head -1)"

echo ">>> javascript-deno environment is working"
