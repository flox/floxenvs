#!/usr/bin/env bash

set -eo pipefail

if ! command -v op >/dev/null 2>&1; then
  echo "Error: 'op' command not found."
  exit 1
fi

echo ">>> op version: $(op --version)"
echo ">>> 1password environment is working"
