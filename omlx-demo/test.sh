#!/usr/bin/env bash

set -eo pipefail

if ! command -v omlx >/dev/null 2>&1; then
  echo "Error: 'omlx' command not found."
  exit 1
fi
echo ">>> omlx ... OK"

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' command not found."
  exit 1
fi
echo ">>> gum ... OK"

echo ">>> omlx-demo environment is working"
