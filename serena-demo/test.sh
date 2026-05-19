#!/usr/bin/env bash

set -eo pipefail

for cmd in serena gum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

serena --help >/dev/null
echo ">>> serena --help ... OK"

for f in sample-project/main.py sample-project/utils.py; do
  if [ ! -f "$f" ]; then
    echo "Error: '$f' missing."
    exit 1
  fi
  echo ">>> $f present"
done

echo ">>> serena-demo environment is working"
